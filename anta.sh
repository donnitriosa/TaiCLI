#!/bin/bash
#
# Task Analysis for TaiCLI
#

# Function to print a header
print_header() {
  echo "========================================================="
  echo "  $1"
  echo "========================================================="
}

# Function to format minutes as hours and minutes
format_time() {
  local minutes=$1
  local hours=$((minutes / 60))
  local mins=$((minutes % 60))
  printf "%dh %02dm" $hours $mins
}

# Function to calculate percentage of 8-hour workday
calc_percentage() {
  local minutes=$1
  local percentage=$(echo "scale=2; ($minutes / 480) * 100" | bc)
  printf "%.1f%%" $percentage
}

# Create directories if they don't exist
mkdir -p reports

# Use temporary files instead of associative arrays
TEMP_DIR=$(mktemp -d)
DAILY_TIME_FILE="$TEMP_DIR/daily_time.txt"
MONTHLY_TIME_FILE="$TEMP_DIR/monthly_time.txt"
MONTHLY_DAYS_FILE="$TEMP_DIR/monthly_days.txt"
DAILY_TASKS_FILE="$TEMP_DIR/daily_tasks.txt"
touch "$DAILY_TASKS_FILE"
touch "$DAILY_TIME_FILE" "$MONTHLY_TIME_FILE" "$MONTHLY_DAYS_FILE"

total_time=0
total_tasks=0

print_header "TASK ANALYSIS REPORT"
echo "Generated on: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# Process all task files in the tasks directory
found_files=false
for file in tasks/*.txt; do
  if [ ! -f "$file" ]; then
    echo "No task files found in tasks directory."
    exit 1
  fi
  
  found_files=true
  echo "Processing file: $file"
  
  # Process the file line by line - avoiding subshell issue
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    
    # Skip the first line (story ID)
    if [ $line_num -eq 1 ]; then
      continue
    fi
    
    # Skip empty lines
    if [ -z "$line" ]; then
      continue
    fi
    
    # Parse the line with pipe delimiter
    IFS='|' read -r TASK_SUBJECT ACTIVITY_DATE START_TIME TIME_SPENT <<< "$line"
    
    # Trim whitespace
    ACTIVITY_DATE=$(echo "$ACTIVITY_DATE" | xargs)
    TIME_SPENT=$(echo "$TIME_SPENT" | xargs)
    
    # Skip lines with missing data
    if [[ -z "$ACTIVITY_DATE" || -z "$TIME_SPENT" ]]; then
      continue
    fi
    
    # Validate date format
    if ! [[ $ACTIVITY_DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      echo "Invalid date format: $ACTIVITY_DATE (skipping)"
      continue
    fi
    
    # Extract month for grouping
    MONTH=$(echo "$ACTIVITY_DATE" | cut -d'-' -f1,2)
    
    # Update daily time
    CURRENT_DAILY=$(grep "^$ACTIVITY_DATE " "$DAILY_TIME_FILE" | cut -d' ' -f2 || echo "0")
    NEW_DAILY=$((CURRENT_DAILY + TIME_SPENT))
    grep -v "^$ACTIVITY_DATE " "$DAILY_TIME_FILE" > "$DAILY_TIME_FILE.tmp"
    echo "$ACTIVITY_DATE $NEW_DAILY" >> "$DAILY_TIME_FILE.tmp"
    mv "$DAILY_TIME_FILE.tmp" "$DAILY_TIME_FILE"
    
    # Update daily tasks count
    CURRENT_TASKS=$(grep "^$ACTIVITY_DATE " "$DAILY_TASKS_FILE" | cut -d' ' -f2 || echo "0")
    NEW_TASKS=$((CURRENT_TASKS + 1))
    grep -v "^$ACTIVITY_DATE " "$DAILY_TASKS_FILE" > "$DAILY_TASKS_FILE.tmp"
    echo "$ACTIVITY_DATE $NEW_TASKS" >> "$DAILY_TASKS_FILE.tmp"
    mv "$DAILY_TASKS_FILE.tmp" "$DAILY_TASKS_FILE"
    
    # Update monthly time
    CURRENT_MONTHLY=$(grep "^$MONTH " "$MONTHLY_TIME_FILE" | cut -d' ' -f2 || echo "0")
    NEW_MONTHLY=$((CURRENT_MONTHLY + TIME_SPENT))
    grep -v "^$MONTH " "$MONTHLY_TIME_FILE" > "$MONTHLY_TIME_FILE.tmp"
    echo "$MONTH $NEW_MONTHLY" >> "$MONTHLY_TIME_FILE.tmp"
    mv "$MONTHLY_TIME_FILE.tmp" "$MONTHLY_TIME_FILE"
    
    # Mark day as counted for this month
    if ! grep -q "^$MONTH,$ACTIVITY_DATE" "$MONTHLY_DAYS_FILE"; then
      echo "$MONTH,$ACTIVITY_DATE" >> "$MONTHLY_DAYS_FILE"
    fi
    
    # Update totals - this will now work correctly since we're not in a subshell
    total_time=$((total_time + TIME_SPENT))
    total_tasks=$((total_tasks + 1))
  done < "$file"
done

if [ "$found_files" = false ]; then
  echo "No task files found in tasks directory."
  exit 1
fi

# Generate Daily Report
print_header "DAILY TIME SPENT"
printf "%-12s %-6s %-10s %-15s %s\n" "DATE" "TASKS" "TIME SPENT" "PERCENTAGE" "WORKLOAD"

# Sort dates and print report
sort "$DAILY_TIME_FILE" | while read -r date minutes; do
  tasks=$(grep "^$date " "$DAILY_TASKS_FILE" | cut -d' ' -f2 || echo "0")
  formatted_time=$(format_time $minutes)
  percentage=$(calc_percentage $minutes)
  
  # Calculate workload indicator
  if (( minutes < 400 )); then
    workload="Low"
  elif (( minutes >= 400 && minutes < 540 )); then
    workload="Fit"
  else
    workload="Overload"
  fi
  
  printf "%-12s %-6s %-10s %-15s %s\n" "$date" "$tasks" "$formatted_time" "$percentage" "$workload"
done

# Generate Monthly Report
print_header "MONTHLY SUMMARY"
printf "%-10s %-12s %-10s %-15s %s\n" "MONTH" "DAYS WORKED" "TIME SPENT" "DAILY AVG" "MONTHLY %"

# Calculate monthly statistics
sort "$MONTHLY_TIME_FILE" | while read -r month minutes; do
  days_worked=$(grep "^$month," "$MONTHLY_DAYS_FILE" | wc -l)
  formatted_time=$(format_time $minutes)
  
  # Calculate daily average
  daily_avg=$((minutes / days_worked))
  formatted_avg=$(format_time $daily_avg)
  
  # Calculate monthly percentage (assuming 22 working days per month)
  monthly_percentage=$(echo "scale=2; ($minutes / (480 * $days_worked)) * 100" | bc)
  
  printf "%-10s %-12s %-10s %-15s %.1f%%\n" "$month" "$days_worked" "$formatted_time" "$formatted_avg" $monthly_percentage
done

# Generate Overall Summary
print_header "OVERALL SUMMARY"
total_days=$(wc -l < "$DAILY_TIME_FILE")
formatted_total=$(format_time $total_time)
if [ "$total_days" -gt 0 ]; then
  daily_avg=$((total_time / total_days))
  formatted_avg=$(format_time $daily_avg)
else
  daily_avg=0
  formatted_avg="0h 00m"
fi

echo "Total tasks tracked:   $total_tasks tasks"
echo "Total days worked: $total_days days"
echo "Total time tracked:    $formatted_total"
echo "Daily average:         $formatted_avg ($(calc_percentage $daily_avg) of 8h workday)"

# Save report to file
report_file="reports/analysis_report_$(date '+%Y%m').txt"
{
  # Report content
  print_header "TASK ANALYSIS REPORT"
  echo "Generated on: $(date '+%Y-%m-%d %H:%M:%S')"
  echo
  
  # Daily report section
  print_header "DAILY TIME SPENT"
  printf "%-12s %-6s %-10s %-15s %s\n" "DATE" "TASKS" "TIME SPENT" "PERCENTAGE" "WORKLOAD"
  sort "$DAILY_TIME_FILE" | while read -r date minutes; do
    tasks=$(grep "^$date " "$DAILY_TASKS_FILE" | cut -d' ' -f2 || echo "0")
    formatted_time=$(format_time $minutes)
    percentage=$(calc_percentage $minutes)

    if (( minutes < 400 )); then
      workload="Low"
    elif (( minutes >= 400 && minutes < 540 )); then
      workload="Fit"
    else
      workload="Overload"
    fi
    
    printf "%-12s %-6s %-10s %-15s %s\n" "$date" "$tasks" "$formatted_time" "$percentage" "$workload"
  done
  
  # Monthly report section
  print_header "MONTHLY SUMMARY" 
  printf "%-10s %-12s %-10s %-15s %s\n" "MONTH" "DAYS WORKED" "TIME SPENT" "DAILY AVG" "MONTHLY %"
  sort "$MONTHLY_TIME_FILE" | while read -r month minutes; do
    days_worked=$(grep "^$month," "$MONTHLY_DAYS_FILE" | wc -l)
    formatted_time=$(format_time $minutes)
    daily_avg=$((minutes / days_worked))
    formatted_avg=$(format_time $daily_avg)
    monthly_percentage=$(echo "scale=2; ($minutes / (480 * $days_worked)) * 100" | bc)
    printf "%-10s %-12s %-10s %-15s %.1f%%\n" "$month" "$days_worked" "$formatted_time" "$formatted_avg" $monthly_percentage
  done
  
  # Summary section
  print_header "OVERALL SUMMARY"
  echo "Total tasks tracked : $total_tasks tasks"
  echo "Total days worked   : $total_days days"
  echo "Total time tracked  : $formatted_total"
  echo "Daily average       : $formatted_avg ($(calc_percentage $daily_avg) of 8h workday)"
} > "$report_file"

# Clean up temp files
rm -rf "$TEMP_DIR"

echo
echo "Report saved to: $report_file"