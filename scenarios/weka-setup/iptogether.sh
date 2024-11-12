index=0
while IFS= read -r line; do
      ip_array[$index]="$line"
        index=$((index + 1))
    done < public-backends.txt

    # Example: Print all IPs
     for ip in "${ip_array[@]}"; do
       echo "$ip"
       done
