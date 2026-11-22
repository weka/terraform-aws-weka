package common

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbiface"
	"github.com/weka/go-cloud-lib/protocol"
)

// fakeDynamo is an in-memory single-item table with real conditional semantics on Version.
type fakeDynamo struct {
	dynamodbiface.DynamoDBAPI
	mu             sync.Mutex
	item           map[string]*dynamodb.AttributeValue
	updateCalls    int
	alwaysConflict bool
}

func newFake(t *testing.T, withVersion bool) *fakeDynamo {
	t.Helper()
	value, err := dynamodbattribute.Marshal(protocol.ClusterState{InitialSize: 100})
	if err != nil {
		t.Fatal(err)
	}
	item := map[string]*dynamodb.AttributeValue{"Key": {S: aws.String("k")}, "Value": value}
	if withVersion {
		item["Version"] = &dynamodb.AttributeValue{N: aws.String("0")}
	}
	return &fakeDynamo{item: item}
}

func (f *fakeDynamo) version() int64 {
	var v int64
	if a, ok := f.item["Version"]; ok {
		_ = dynamodbattribute.Unmarshal(a, &v)
	}
	return v
}

func (f *fakeDynamo) GetItem(in *dynamodb.GetItemInput) (*dynamodb.GetItemOutput, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	cp := map[string]*dynamodb.AttributeValue{}
	for k, v := range f.item {
		cp[k] = v
	}
	return &dynamodb.GetItemOutput{Item: cp}, nil
}

func (f *fakeDynamo) UpdateItem(in *dynamodb.UpdateItemInput) (*dynamodb.UpdateItemOutput, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.updateCalls++
	conflict := awserr.New(dynamodb.ErrCodeConditionalCheckFailedException, "conflict", nil)
	if f.alwaysConflict {
		return nil, conflict
	}
	// The expression carries two numbers, the expected version and that +1, so the smaller is the expected one.
	var nums []int64
	var newValue *dynamodb.AttributeValue
	for _, v := range in.ExpressionAttributeValues {
		if v.N != nil {
			var n int64
			_ = dynamodbattribute.Unmarshal(v, &n)
			nums = append(nums, n)
		}
		if v.M != nil {
			newValue = v
		}
	}
	oldVersion := min(nums[0], nums[1])
	// Condition: attribute_not_exists(Version) OR Version = old
	if _, ok := f.item["Version"]; ok && oldVersion != f.version() {
		return nil, conflict
	}
	f.item["Value"] = newValue
	f.item["Version"] = &dynamodb.AttributeValue{N: aws.String(fmt.Sprint(oldVersion + 1))}
	return &dynamodb.UpdateItemOutput{}, nil
}

func fastBackoff(t *testing.T) {
	oldBase, oldMax := stateUpdateBackoffBase, stateUpdateBackoffMax
	stateUpdateBackoffBase, stateUpdateBackoffMax = time.Microsecond, 100*time.Microsecond
	t.Cleanup(func() { stateUpdateBackoffBase, stateUpdateBackoffMax = oldBase, oldMax })
}

func (f *fakeDynamo) state(t *testing.T) protocol.ClusterState {
	var item StateItem
	if err := dynamodbattribute.UnmarshalMap(f.item, &item); err != nil {
		t.Fatal(err)
	}
	return item.Value
}

func update(f *fakeDynamo, mutate func(*protocol.ClusterState) error) (protocol.ClusterState, error) {
	return updateClusterState(context.Background(), f, "t", "Key", "k", mutate)
}

func TestConcurrentUpdates(t *testing.T) {
	fastBackoff(t)
	f := newFake(t, true)
	const n = 8
	var wg sync.WaitGroup
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if _, err := update(f, func(s *protocol.ClusterState) error {
				s.Instances = append(s.Instances, protocol.Vm{Name: fmt.Sprintf("i-%d", i)})
				return nil
			}); err != nil {
				t.Error(err)
			}
		}(i)
	}
	wg.Wait()
	if got := len(f.state(t).Instances); got != n {
		t.Fatalf("expected %d instances, got %d", n, got)
	}
	if v := f.version(); v != n {
		t.Fatalf("expected version %d, got %d", n, v)
	}
}

func TestMissingVersionAttribute(t *testing.T) {
	fastBackoff(t)
	f := newFake(t, false)
	_, err := update(f, func(s *protocol.ClusterState) error {
		s.Clusterized = true
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if !f.state(t).Clusterized || f.version() != 1 {
		t.Fatalf("unexpected result: clusterized=%v version=%d", f.state(t).Clusterized, f.version())
	}
}

func TestMutateErrorNotRetried(t *testing.T) {
	fastBackoff(t)
	f := newFake(t, true)
	want := errors.New("validation failed")
	calls := 0
	_, err := update(f, func(s *protocol.ClusterState) error {
		calls++
		return want
	})
	if !errors.Is(err, want) || calls != 1 || f.updateCalls != 0 {
		t.Fatalf("err=%v calls=%d updates=%d", err, calls, f.updateCalls)
	}
}

func tinyBudget(t *testing.T, budget, margin time.Duration) {
	oldBudget, oldMargin := stateUpdateBudget, stateUpdateDeadlineMargin
	stateUpdateBudget, stateUpdateDeadlineMargin = budget, margin
	t.Cleanup(func() { stateUpdateBudget, stateUpdateDeadlineMargin = oldBudget, oldMargin })
}

func TestPersistentConflictExhaustsBudget(t *testing.T) {
	fastBackoff(t)
	tinyBudget(t, 20*time.Millisecond, time.Second)
	f := newFake(t, true)
	f.alwaysConflict = true
	start := time.Now()
	_, err := update(f, func(s *protocol.ClusterState) error { return nil })
	if !errors.Is(err, errStateUpdateConflict) {
		t.Fatalf("expected conflict error, got %v", err)
	}
	if elapsed := time.Since(start); elapsed > 500*time.Millisecond {
		t.Fatalf("took too long: %v", elapsed)
	}
	if f.updateCalls < 2 {
		t.Fatalf("expected more than one attempt, got %d", f.updateCalls)
	}
}

func TestContextStopsRetrying(t *testing.T) {
	tests := []struct {
		name string
		ctx  func() (context.Context, context.CancelFunc)
	}{
		{"deadline within margin", func() (context.Context, context.CancelFunc) {
			return context.WithTimeout(context.Background(), 500*time.Millisecond) // inside the 1s margin
		}},
		{"already cancelled", func() (context.Context, context.CancelFunc) {
			ctx, cancel := context.WithCancel(context.Background())
			cancel()
			return ctx, cancel
		}},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// Backoff well above timer resolution so ctx.Done() reliably wins the select.
			oldBase, oldMax := stateUpdateBackoffBase, stateUpdateBackoffMax
			stateUpdateBackoffBase, stateUpdateBackoffMax = 20*time.Millisecond, 20*time.Millisecond
			t.Cleanup(func() { stateUpdateBackoffBase, stateUpdateBackoffMax = oldBase, oldMax })
			tinyBudget(t, time.Minute, time.Second)
			f := newFake(t, true)
			f.alwaysConflict = true
			ctx, cancel := tc.ctx()
			defer cancel()
			_, err := updateClusterState(ctx, f, "t", "Key", "k", func(s *protocol.ClusterState) error { return nil })
			if !errors.Is(err, errStateUpdateConflict) {
				t.Fatalf("expected conflict error, got %v", err)
			}
			if f.updateCalls != 1 {
				t.Fatalf("expected a single attempt, got %d", f.updateCalls)
			}
		})
	}
}
