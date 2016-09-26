#!/usr/bin/env bats

BISHOP_COMMANDS_FILE=`pwd`/test/test_commands.json
. bishop.sh

function stubSuggestedWords() {
    actualSuggestedWords=$1
    actualCurrentCommand=$2
}

function stubCommandCompletion() {
    actualCurrentCommand=$1
}

function stubTabPressedTwice() {
    tabbedPressedTwiceWithCurrentCommand=$1
}

function noOp() {
    return 0
}

COMP_WORDS=("bishop" "files" "")
COMP_CWORD=1

# end to end
@test "bishop executes command" {
    output=$(bishop files ls)
    echo $output | grep "bishop.sh" #returns a line
}

# high level
@test "suggests keys in json tree below current command" {
  COMP_WORDS=("bishop" "files" "")
  COMP_CWORD=1
  _processCompletion stubSuggestedWords noOp noOp
  echo $actualSuggestedWords
  [ "$actualSuggestedWords" == "listDetails ls" ]
  [ "$actualCurrentCommand" == "files" ]
}

@test "resolves to static command when on leaf of json tree" {
  COMP_WORDS=("bishop" "files" "listDetails" "")
  COMP_CWORD=1
  _processCompletion noOp stubCommandCompletion noOp
  [ "$actualCurrentCommand" == "ls -al" ]
}

@test "increments tab count when processing completion" {
  COMP_WORDS=("bishop" "files" "listDetails" "")
  COMP_CWORD=1
  CURRENT_TAB_COUNT=0
  _processCompletion noOp stubCommandCompletion noOp
  [ $CURRENT_TAB_COUNT -eq 1 ]
  _processCompletion noOp stubCommandCompletion noOp
  [ $CURRENT_TAB_COUNT -eq 2 ]
}

@test "invokes tab pressed twice function when tab has been pressed twice" {
  COMP_WORDS=("bishop" "files" "listDetails" "")
  COMP_CWORD=1
  CURRENT_TAB_COUNT=2
  _processCompletion noOp stubCommandCompletion stubTabPressedTwice
  [ "$tabbedPressedTwiceWithCurrentCommand" == "ls -al" ]
}

@test "inserts variables into commands" {
  COMP_WORDS=("bishop" "prod" "secure" "shell" "")
  COMP_CWORD=1
  _processCompletion noOp stubCommandCompletion noOp
  echo $actualCurrentCommand
  [ "$actualCurrentCommand" == "ssh -i file.id_rsa theUser@theServer" ]
}

@test "_walkJsonAndCreateVariables creates variables for all levels of the json tree" {
  COMP_WORDS=("bishop" "prod" "secure" "copy" "")
  COMP_CWORD=1
  CURRENT_TAB_COUNT=0
  _walkJsonAndCreateVariables
}

# unit
@test "_jsonSelector builds jq json selector given current word list" {
  COMP_WORDS=("bishop" "files" "")
  COMP_CWORD=1
  selector=$(_jsonSelector)
  [ "$selector" == ".[].files" ]
}

@test "_resolveCommand retrieves json object at selector position in commands file" {
   command=$(_resolveCommand ".[].files")
   echo $command
   [ "$command" == "{ \"ls\": \"ls\", \"listDetails\": \"ls -al\" }" ]
}

@test "_resolveCommand retrieves string when selector represents a leaf in the commands json" {
   command=$(_resolveCommand ".[].files.listDetails")
   [ "$command" == "ls -al" ]
}

@test "_resolveCommand returns null when no match to given selector" {
   command=$(_resolveCommand ".[].files.bobbins")
   [ "$command" == null ]
}

@test "_parseJsonCommands returns non variable commands" {
   commands=$(_parseJsonCommands "{\"ls\": \"ls\", \"\$variable\":\"value\"}")
   echo $commands
   [ "$commands" == "ls" ]
}

@test "_parseJsonVariables returns variable commands" {
   variables=$(_parseJsonVariables "{\"ls\": \"ls\", \"_variable\":\"value\"}")
   echo $variables
   [ "$variables" == "_variable" ]
}

#@test "_commandCompleted outputs command in yellow" {
#    output=$(_commandCompleted "ls -al")
#    expected=$(tput sc; echo -e "\033[0;33m   <- ls -al\033[0m"; tput rc)
#    echo $output
#    echo $expected
#    [ "$output" == "$expected" ]
#}