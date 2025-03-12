#!/usr/bin/bash

if [[ $# -ne 2 || $1 != "-i" || ! -f $2 ]]; then
    echo "You have given wrong command"
    exit 1
fi

# Taking input in variables from file
fileName=$2
{
    read use_Archive
    read allowed_Archived_Formats
    read allowed_Prog_Languages
    read total_Marks
    read penalty_For_Unmatched
    read working_Directory
    read student_Id_Range
    read expected_Output_File_Loc
    read penalty_For_Guideline
    read plagiarism_Analysis_File
    read plagiarism_Penalty
} < "$fileName"

languageType=("c" "cpp" "python" "sh")

# Trim any leading/trailing whitespace or newlines
use_Archive=$(echo "$use_Archive" | tr -d '\r' | xargs)
allowed_Archived_Formats=$(echo "$allowed_Archived_Formats" | tr -d '\r' | xargs)
allowed_Prog_Languages=$(echo "$allowed_Prog_Languages" | tr -d '\r' | xargs)
total_Marks=$(echo "$total_Marks" | tr -d '\r' | xargs)
penalty_For_Unmatched=$(echo "$penalty_For_Unmatched" | tr -d '\r' | xargs)
working_Directory=$(echo "$working_Directory" | tr -d '\r' | xargs)
student_Id_Range=$(echo "$student_Id_Range" | tr -d '\r' | xargs)
expected_Output_File_Loc=$(echo "$expected_Output_File_Loc" | tr -d '\r' | xargs)
penalty_For_Guideline=$(echo "$penalty_For_Guideline" | tr -d '\r' | xargs)
plagiarism_Analysis_File=$(echo "$plagiarism_Analysis_File" | tr -d '\r' | xargs)
plagiarism_Penalty=$(echo "$plagiarism_Penalty" | tr -d '\r' | xargs)

# Split the student ID range into an array
IFS=' ' read -r -a student_id_range <<< "$student_Id_Range"
IFS=' ' read -r -a allowed_format <<< "$allowed_Archived_Formats"
IFS=' ' read -r -a allowed_lang <<< "$allowed_Prog_Languages"

MISSING_REMARK="missing submission"

# Task 1: Input File Processing
if [[ $use_Archive != "true" && $use_Archive != "false" ]]; then 
    echo "Use Archive is not correct format"
    exit 1
fi

if [[ "$use_Archive" == "true" && ! "$allowed_Archived_Formats" =~ ^(zip|rar|tar)( (zip|rar|tar))*$ ]]; then
    echo "Archieved Format is not correct"
    exit 1
fi

if [[ ! "$allowed_Prog_Languages" =~ ^(c|cpp|python|sh)( (c|cpp|python|sh))*$ ]]; then
    echo "Programming Language is not supported"
    exit 1
fi

if ! [[ "$total_Marks" =~ ^[0-9]+$ ]] || [ "$total_Marks" -le 0 ]; then
    echo "Total marks can't be zero or negative and must contain (0-9)"
    exit 1
fi

if ! [[ "$penalty_For_Unmatched" =~ ^[0-9]+$ ]] || [ "$penalty_For_Unmatched" -le 0 ]; then
    echo "Penalty Marks can't be negative and must contain (0-9)"
    exit 1
fi

if [[ ! -d "$working_Directory" ]]; then
    echo "Working Directory does not exist"
    exit 1
fi

if ! [[ "${student_id_range[0]}" =~ ^[0-9]+$ && "${student_id_range[1]}" =~ ^[0-9]+$ && "${student_id_range[0]}" -le "${student_id_range[1]}" ]]; then
    echo "Student ID Range must contain two valid integers"
    exit 1
fi

if [[ ! -f "$expected_Output_File_Loc" ]]; then
    echo "Expected Output File does not exist"
    exit 1
fi

if ! [[ "$penalty_For_Guideline" =~ ^[0-9]+$ ]] || [ "$penalty_For_Guideline" -le 0 ]; then
    echo "Penalty Marks for violation of guideline can't be negative and must contain (0-9)"
    exit 1
fi

if [[ ! -f "$plagiarism_Analysis_File" ]]; then
    echo "Plagiarism Analysis File does not exist"
    exit 1
fi

if ! [[ "$plagiarism_Penalty" =~ ^[0-9]+$ ]] || [ "$plagiarism_Penalty" -le 0 ]; then
    echo "Penalty Marks for plagiarism can't be negative and must contain (0-9)"
    exit 1
fi

mkdir -p "$working_Directory/issues/" "$working_Directory/checked/"
#For deleting all previous contents
rm -rf "$working_Directory/issues"/* "$working_Directory/checked"/*

declare -a plagiarism_lines
while IFS= read -r line || [[ -n "$line" ]]; do
    # Append each line to the array
    plagiarism_lines+=("$line")
done < "$plagiarism_Analysis_File"

#To compare outputs
compare_outputs() {
    local output_file="$1"
    local expected_file="$2"
    local penalty="$3"
    local marks_deduction=0 #"$4"
    #Reading file into array
    mapfile -t expected_lines < "$expected_file"

    for expected_line in "${expected_lines[@]}"; do
        #Check if the line exists in the output file
        if ! grep -Fxq "$expected_line" "$output_file"; then
            marks_deduction=$((marks_deduction + penalty))
        fi
    done
    echo $marks_deduction
}


CSV_FILE="$working_Directory/marks.csv"
# Initialize the CSV file 
echo "id, marks, marks_deducted, total_marks, remarks" > $CSV_FILE
#for student_file in "$working_Directory"/*; do

for (( counter="${student_id_range[0]}"; counter<="${student_id_range[1]}"; counter++ )); 
do
    deduct_mark=0
    student_file=$(find "$working_Directory" -maxdepth 1 -name "${counter}" -o -name "${counter}.*")
    if [ -z "$student_file" ]; then
        # If no submission is found
        echo "$counter,0,0,$total_Marks,$MISSING_REMARK" >> $CSV_FILE
        continue 
    fi
    student_id=$(basename "$student_file" | cut -d. -f1)

    if ! [[ $student_id -ge "${student_id_range[0]}" && $student_id -le "${student_id_range[1]}" ]]; then
        continue
    fi

    remarks=""
    marks_deduction=0
    it_is_file=false
    # Determine if the file is an archive
    archive_Extension="${student_file##*.}"

    # Check if the archive extension is allowed
    is_allowed=false
    for format in "${allowed_format[@]}"; do
        if [[ "$archive_Extension" == "$format" ]]; then
            is_allowed=true
            break
        fi
    done

    if [[ $archive_Extension == $student_file ]]; then
        is_allowed=true
    fi

    file_Ext="${archive_Extension##*.}"
    for file_format in "${languageType[@]}"; do
        if [[ $file_format == "python" ]]; then
            file_format="py"
        fi
        if [[ "$file_Ext" == "$file_format" ]]; then
            is_allowed="true"
            it_is_file="true"
            break
        fi
    done

    if [[ "$is_allowed" == "false" ]]; then
        temp_file=$(basename "$student_file")
        # if [[ "$temp_file" == "expected_output.txt" || "$temp_file" == "plagiarism.txt" || "$temp_file" == "input_file.txt" ]]; then
        #     continue
        # fi
        marks_deduction=0
        remarks="issue case #2"
        if [[ $it_is_file == "true" ]]; then
            remarks="issue case #3"
            mv "$student_file" "$working_Directory/issues/"
        fi
        echo "$student_id,0,$penalty_For_Guideline,-$penalty_For_Guideline,$remarks" >> $CSV_FILE
        # mv "$student_file" issues/
        continue

    #Working on zip (working Directory student file,archive Extension)
    else
        mkdir -p "$working_Directory/submitted"
        submission_Directory="$working_Directory/submitted"
        if [ $it_is_file == "true" ]; then
            mkdir -p "$submission_Directory/$student_id"
            submission_Di="$submission_Directory/$student_id"
            if [[ $use_Archive == "true" ]]; then
                marks_deduction=$((marks_deduction + penalty_For_Guideline))
                remarks+="issue case #1"
            fi
            mv $student_file $submission_Di
        else
            # mkdir -p "$working_Directory/submitted"
            # submission_Directory="$working_Directory/submitted"
            if [[ $archive_Extension == $student_file ]]; then
                #marks_deduction=$((marks_deduction + penalty_For_Guideline)) 
                mv "$student_file" "$submission_Directory/"
                submission_Di="$submission_Directory/$student_id"
                if [[ $use_Archive == "true" ]]; then
                    marks_deduction=$((marks_deduction + penalty_For_Guideline))
                    #remarks+="The submission is a folder.Not a zip/tar/rar format."
                    deduct_mark=$((deduct_mark + penalty_For_Guideline))
                    remarks+="issue case #1"
                fi
            else
                # Unarchive the file
                case $archive_Extension in
                    zip) 
                        unzip "$student_file" -d "$submission_Directory" 
                        ;;
                    rar) 
                        unrar x "$student_file" "$submission_Directory" 
                        ;;
                    tar) 
                        tar -xf "$student_file" -C "$submission_Directory" 
                        ;;
                esac

                # extracted folder
                extracted_dir=$(find "$submission_Directory" -mindepth 1 -maxdepth 1 -type d)
                # if [[ -z "$extracted_dir" ]]; then
                #     echo "No extracted folder found for $student_file"
                #     mv "$student_file" issues/
                #     continue
                # fi

                if [[ $use_Archive == "false" ]]; then
                    marks_deduction=$((marks_deduction + penalty_For_Guideline))
                    #remarks+="The submission is in a $archive_Extension format."
                    remarks+="issue case #1"
                fi
                # #Check if the folder contains ID name
                originalFolder=$(basename "$extracted_dir")

                new_folder_parent="$(dirname "$extracted_dir")"
                new_folder="$new_folder_parent/$student_id"

                if [[ $originalFolder != $student_id ]]; then

                    #Renaming the folder by mv "$old_folder" "$(dirname "$old_folder")/$new_folder" 

                    mv "$extracted_dir" "$new_folder"
                    marks_deduction=$((marks_deduction + penalty_For_Guideline))
                    deduct_mark=$((deduct_mark + penalty_For_Guideline))
                    remarks+="issue case #4"
                    extracted_dir="$new_folder"

                fi
                # Update the submission directory path
                submission_Di="$extracted_dir"
            fi
        fi
    fi
    
    student_output="$submission_Di/${student_id}_output.txt"
    check="false"

    for s_file in "$submission_Di"/*; do
        isfile="false"
        file_Extension="${s_file##*.}"
        for file_format in "${allowed_lang[@]}"; do
            if [[ $file_format == "python" ]]; then
                file_format="py"
            fi
            if [[ "$file_Extension" == "$file_format" ]]; then
                isfile="true"
                break
            fi
        done
        
        if [[ "$isfile" == "false" ]]; then
            remarks+="issue case #3"
            #marks_deduction=$((marks_deduction + penalty_For_Guideline))
            marks_deduction=$penalty_For_Guideline
            check="true"
            break
        else
            program_file=$(basename "$s_file")
            originalFile=$(basename "$program_file" | cut -d. -f1)
            if [[ $originalFile != $student_id ]]; then
                marks_deduction=$((marks_deduction + penalty_For_Guideline))
            fi
            case $file_Extension in
                c) gcc "$s_file" -o "$s_file.o" && "$s_file.o" > "$student_output" 
                    ;;
                cpp) g++ "$s_file" -o "$s_file.o" && "$s_file.o" > "$student_output" 
                    ;;
                py) python3 "$s_file" > "$student_output" 
                    ;;
                sh) bash "$s_file" > "$student_output" 
                    ;;
            esac
        fi
    done
    
    if [[ "$check" == "true" ]]; then
        echo "$student_id,0,$marks_deduction,-$marks_deduction,$remarks" >> $CSV_FILE
        #echo "$student_id,0,\"$penalty_For_Guideline\",-\"$penalty_For_Guideline\",\"$remarks\"" >> $CSV_FILE
        mv "$submission_Di" "$working_Directory/issues"
        continue
    fi
    
    # Compare outputs and calculate deductions
    marks_deduction=$(compare_outputs "$student_output" "$expected_Output_File_Loc" "$penalty_For_Unmatched" "$marks_deduction")
 
    candidate=false
    for line in "${plagiarism_lines[@]}"; do
        if [[ $line == "$student_id" ]]; then
            remarks+="plagiarism detected"
            candidate=true
        fi
    done

    final_marks=$(( total_Marks - marks_deduction ))

    deducted_final_mark=$(( final_marks - deduct_mark ))

    # Append the result for the current student to the CSV
    if [ $candidate == "true" ]; then
        #marks_deduction=$((marks_deduction + plagiarism_Penalty))
        echo "$student_id,$final_marks,0,-100,$remarks" >> $CSV_FILE
    else
        echo "$student_id,$final_marks,$deduct_mark,$deducted_final_mark,$remarks" >> $CSV_FILE
    fi
    #done
    # Move submission to checked directory
    mv "$submission_Di" "$working_Directory/checked/"
    #rm -r "$submission_Directory"
done
rm -r "$submission_Directory"
