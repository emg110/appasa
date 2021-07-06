echo "
    ___                   ___    _____  ___ 
   /   |   ____   ____   /   |  / ___/ /   |
  / /| |  / __ \ / __ \ / /| |  \__ \ / /| |
 / ___ | / /_/ // /_/ // ___ | ___/ // ___ |
/_/  |_|/ .___// .___//_/  |_|/____//_/  |_|
       /_/    /_/                           
"
date '+ Running algorand-gitcoin-bounty-appasa | by @emg110 | %Y/%m/%d %H:%M:%S |'
echo "----------------------------------------------------------------------------"
echo "                       "
set -o pipefail
export SHELLOPTS
set -e
#set -x



goalcli="../sandbox/sandbox goal"
tealdbgcli="../sandbox/sandbox tealdbg"
sandboxcli="../sandbox/sandbox"
ACC=$( ${goalcli} account list | awk '{ print $3 }' | tail -1)
APPROVAL_PROG="appasa-approval-prog.teal"
CLEAR_PROG="appasa-clear-prog.teal"
ESCROW_PROG="appasa-escrow-prog.teal"
case $1 in
install)
echo "Installing sandbox environment"
cd "../" && git clone https://github.com/algorand/sandbox
echo "Algorand Sandbox installed in parent folder (Beside current folder)"
cd algorand-gitcoin-bounty-appasa
;;
reset)
echo "Reseting sandbox environment"
rm -f appasa-asset-index.txt
rm -f appasa-id.txt
rm -f appasa-escrow-prog-snd.txt
rm -f appasa-escrow-account.txt
rm -f appasa-main-account.txt
$sandboxcli reset
;;
stop)
echo "Stopping sandbox environment"
$sandboxcli down
;;
start)
echo "Starting sandbox environment"
$sandboxcli up
;;
asc)
rm -f appasa-id.txt
rm -f appasa-escrow-prog-snd.txt
rm -f appasa-escrow-account.txt
rm -f appasa-main-account.txt
cp "$APPROVAL_PROG" "$CLEAR_PROG" ../sandbox
$sandboxcli copyTo "$APPROVAL_PROG"
$sandboxcli copyTo "$CLEAR_PROG"
APP=$(
  ${goalcli} app create --creator "${ACC}" --clear-prog "$CLEAR_PROG" --approval-prog "$APPROVAL_PROG" \
    --global-byteslices 1 \
    --local-byteslices 0 \
    --global-ints 1 \
    --local-ints 0 |
    grep Created |
    awk '{ print $NF }'
)
echo -ne "${APP}" > "appasa-id.txt"
cat $ESCROW_PROG | awk -v awk_var=${APP} '{ gsub("appIdParam", awk_var); print}' > "appasa-escrow-prog-snd.teal"
ESCROW_PROG_SND="appasa-escrow-prog-snd.teal"
$sandboxcli copyTo "$ESCROW_PROG_SND"
ESCROW_ACCOUNT=$(
  ${goalcli} clerk compile -a ${ACC} -n ${ESCROW_PROG_SND} | awk '{ print $2 }' | head -n 1
)
echo -ne "${ACC}" > "appasa-main-account.txt"
echo -ne "${ESCROW_ACCOUNT}" > "appasa-escrow-account.txt"
echo "Stateful Application ID $APP"
echo "Stateless Escrow Account = ${ESCROW_ACCOUNT}"
;;
fund)
AMOUNT=$2
MAIN_ACC=$(<appasa-main-account.txt)
ESCROW_ACC=$(cat "appasa-escrow-account.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
ESCROW_ACC_TRIM="${ESCROW_ACC//$'\r'/ }"
${goalcli} clerk send -a ${AMOUNT} -f "${MAIN_ACC}" --to ${ESCROW_ACC_TRIM}
;;
escrowbal)
echo "Getting the escrow account balance..."
ESCROW_ACC=$(cat "appasa-escrow-account.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
ESCROW_ACC_TRIM="${ESCROW_ACC//$'\r'/ }"
echo "Escrfow account:$ESCROW_ACC_TRIM" 
${goalcli} account balance -a $ESCROW_ACC_TRIM
;;
mainbal)
echo "Getting the main account balance..."
MAIN_ACC=$(<appasa-main-account.txt)
echo "Main account:$MAIN_ACC" 
${goalcli} account balance -a $MAIN_ACC
;;
escrow)
echo "Getting the escrow account info..."
ESCROW_ACC=$(cat "appasa-escrow-account.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
ESCROW_ACC_TRIM="${ESCROW_ACC//$'\r'/ }"
echo "Escrow account:$ESCROW_ACC_TRIM" 
${goalcli} account info -a $ESCROW_ACC_TRIM
;;
main)
echo "Getting the main account info..."
MAIN_ACC=$(<appasa-main-account.txt)
echo "Main account:$MAIN_ACC" 
${goalcli} account info -a $MAIN_ACC
;;
link)
echo "Linking stateless escrow account to stateful smart contract"
MAIN_ACC=$(<appasa-main-account.txt)
ESCROW_ACC=$(cat "appasa-escrow-account.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
ESCROW_ACC_TRIM="${ESCROW_ACC//$'\r'/ }"
ESCROW_ACC_TRIMM="${ESCROW_ACC//$'\n'/ }"
APP_ID=$(cat "appasa-id.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
APP_ID_TRIM="${APP_ID//$'\r'/ }"
echo "Escrow account: $ESCROW_ACC_TRIMM"
echo "Main account:$MAIN_ACC"
echo "Application ID:$APP_ID_TRIM"
${goalcli} app call --app-id ${APP_ID_TRIM} --app-arg "str:escrow_set" --app-arg "addr:${ESCROW_ACC_TRIMM}" -f ${MAIN_ACC}
${goalcli} app read --app-id ${APP_ID_TRIM} --guess-format --global --from ${MAIN_ACC}
;;
asa)
echo "Generating Standard Asset..."
ASSET_INDEX=0
if [ $2 = "auto" ]; then
  echo "Auto mode selected..."
  if [[ -f "appasa-asset-index.txt" ]]; then
    echo "File found..."
    ASSET_INDEX_STR=$(cat "appasa-asset-index.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
    ASSET_INDEX_STR_TRIM="${ASSET_INDEX_STR//$'\r'/ }"
    echo "Auto AppASA index (counter) setting selected! Previous index found: ${ASSET_INDEX_STR_TRIM}"
    
    ASSET_INDEX="$((ASSET_INDEX_STR_TRIM + 1))"
    echo "Next index counter calculated: ${ASSET_INDEX}"

    
    rm -f appasa-asset-index.txt
    echo -ne "${ASSET_INDEX}" > "appasa-asset-index.txt"
  else
  echo "File not found..."
    echo "Auto AppASA index (counter) setting selected! Previous index not found: AppASA index counter set to 0"
    echo -ne "${ASSET_INDEX}" > "appasa-asset-index.txt"
  fi
else
    echo "Manual counting mode selected! AppASA index counter set to ${2}"
    ASSET_INDEX="$2"
    echo -ne "${ASSET_INDEX}" > "appasa-asset-index.txt" 
fi

MAIN_ACC=$(<appasa-main-account.txt)
ESCROW_ACC=$(cat "appasa-escrow-account.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
ESCROW_ACC_TRIM="${ESCROW_ACC//$'\r'/ }"
APP_ID=$(cat "appasa-id.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
APP_ID_TRIM="${APP_ID//$'\r'/ }"
ESCROW_PROG_SND="appasa-escrow-prog-snd.teal"
$sandboxcli copyTo "$ESCROW_PROG_SND"
echo "Escrow account: $ESCROW_ACC_TRIM"
echo "Main account: $MAIN_ACC"
echo "Application ID:$APP_ID_TRIM"
echo "The asset name (AppASA-x) counter (x):$ASSET_INDEX x: AppASA-$ASSET_INDEX"
${goalcli} app call --app-id ${APP_ID_TRIM} --app-arg "str:asa_cfg" -f ${MAIN_ACC} -o trx-call-app-unsigned.tx
$sandboxcli copyFrom "trx-call-app-unsigned.tx"
${goalcli} asset create --creator ${ESCROW_ACC_TRIM} --name "AppASA-$ASSET_INDEX" --total 99999999 --decimals 0 -o trx-create-asa-unsigned.tx
$sandboxcli copyFrom "trx-create-asa-unsigned.tx"
cat trx-call-app-unsigned.tx trx-create-asa-unsigned.tx > trx-array-asa-unsigned.tx
$sandboxcli copyTo "trx-array-asa-unsigned.tx"
${goalcli} clerk group -i trx-array-asa-unsigned.tx -o group-trx-asa-unsigned.tx
$sandboxcli copyFrom "group-trx-asa-unsigned.tx"
${goalcli} clerk split -i group-trx-asa-unsigned.tx -o trx-asa-unsigned-index.tx
$sandboxcli copyFrom "trx-asa-unsigned-index-0.tx"
$sandboxcli copyFrom "trx-asa-unsigned-index-1.tx"
${goalcli} clerk sign -i trx-asa-unsigned-index-0.tx -o trx-asa-signed-index-0.tx
$sandboxcli copyFrom "trx-asa-signed-index-0.tx"
${goalcli} clerk sign -i trx-asa-unsigned-index-1.tx -p ${ESCROW_PROG_SND} -o trx-asa-signed-index-1.tx
$sandboxcli copyFrom "trx-asa-signed-index-1.tx"
cat trx-asa-signed-index-0.tx trx-asa-signed-index-1.tx > trx-group-asa-signed.tx
$sandboxcli copyTo "trx-group-asa-signed.tx"
echo "Sending signed transaction group with clerk..."
${goalcli} clerk rawsend -f trx-group-asa-signed.tx
rm -f *.tx
rm -f *.rej
rm -f awk
rm -f head
rm -f *.scratch
rm -f *.json
rm -f sed
;;

dryrun)
echo "Creating Dry-run dump from signed transaction group..."
${goalcli} clerk dryrun -t trx-group-asa-signed.tx --dryrun-dump -o trx-group-asa-signed-dryrun.json
$sandboxcli copyFrom "trx-group-asa-signed-dryrun.json"
echo "Dryrun dump JSON file generated successfully!"
;;

drapproval)
echo "Dry-running signed approval program with signed transaction group ..."
${goalcli} clerk dryrun -t trx-group-asa-signed.tx --dryrun-dump -o trx-group-asa-signed-dryrun.json
$sandboxcli copyFrom "trx-group-asa-signed-dryrun.json"
cd "../" && docker exec -it algorand-sandbox-algod  tealdbg debug ${APPROVAL_PROG} -f cdt --listen 0.0.0.0 -d trx-group-asa-signed-dryrun.json --group-index 0
echo "The Dry run JSON file is running to check Approval Smart Contract"
cd algorand-gitcoin-bounty-appasa


;;
drescrow)
echo "Dry-running signed approval program with signed transaction group..."
${goalcli} clerk dryrun -t trx-group-asa-signed.tx --dryrun-dump -o trx-group-asa-signed-dryrun.json
$sandboxcli copyFrom "trx-group-asa-signed-dryrun.json"
cd "../" && docker exec -it  algorand-sandbox-algod tealdbg debug ${ESCROW_PROG_SND} -f cdt --listen 0.0.0.0 -d trx-group-asa-signed-dryrun.json
echo "The Dry run JSON file is running to check Stateful Approval Smart Contract..."
cd algorand-gitcoin-bounty-appasa
;;

axfer)
ASSET_ID=0

echo "Receiving Standard Asset..."
MAIN_ACC=$(<appasa-main-account.txt)
ESCROW_ACC=$(cat "appasa-escrow-account.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
ESCROW_ACC_TRIM="${ESCROW_ACC//$'\r'/ }"
APP_ID=$(cat "appasa-id.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
APP_ID_TRIM="${APP_ID//$'\r'/ }"


if [ $2 = "auto" ]; then
    ASSET_ID=$(${goalcli} account info -a ${ESCROW_ACC_TRIM} | grep ID | head -n 1 | awk '{ print $2 }')
    echo "The Asset ID selected by auto mode is: ${ASSET_ID%?}"
else
    
    ASSET_ID= $2
    echo "Manual asset ID entering mode selected! Asset ID in request to be transfered (one unit only) ${ASSET_ID%?}"
    echo -ne "${ASSET_ID%?}" > "appasa-asset-index.txt" 
fi

echo "Escrow account: $ESCROW_ACC_TRIM"
echo "Application ID:$APP_ID_TRIM"
echo "The asset ID from which 1 (one) unit will be transfered to main account: ${ASSET_ID%?}"

ESCROW_PROG_SND="appasa-escrow-prog-snd.teal"
${goalcli} asset send --assetid ${ASSET_ID%?} -f ${MAIN_ACC} -t ${MAIN_ACC} -a 0
${goalcli} app call --app-id ${APP_ID_TRIM} --app-arg "str:asa-xfer" -f ${MAIN_ACC} -o trx-get-asa-unsigned.tx
$sandboxcli copyFrom "trx-get-asa-unsigned.tx"
${goalcli} asset send --assetid ${ASSET_ID%?} -f ${ESCROW_ACC_TRIM} -t ${MAIN_ACC} -a 1 -o trx-send-asa-unsigned.tx
$sandboxcli copyFrom "trx-send-asa-unsigned.tx"
cat trx-get-asa-unsigned.tx trx-send-asa-unsigned.tx > trx-array-asa-transfer-unsigned.tx
$sandboxcli copyTo "trx-array-asa-transfer-unsigned.tx"
${goalcli} clerk group -i trx-array-asa-transfer-unsigned.tx -o trx-group-asa-transfer-unsigned.tx
$sandboxcli copyFrom "trx-group-asa-transfer-unsigned.tx"
${goalcli} clerk split -i trx-group-asa-transfer-unsigned.tx -o trx-asa-transfer-unsigned-index.tx
${goalcli} clerk sign -i trx-asa-transfer-unsigned-index-0.tx -o trx-asa-transfer-signed-index-0.tx
${goalcli} clerk sign -i trx-asa-transfer-unsigned-index-1.tx -p ${ESCROW_PROG_SND} -o trx-asa-transfer-signed-index-1.tx
$sandboxcli copyFrom "trx-asa-transfer-signed-index-0.tx"
$sandboxcli copyFrom "trx-asa-transfer-signed-index-1.tx"
cat trx-asa-transfer-signed-index-0.tx trx-asa-transfer-signed-index-1.tx > trx-group-asa-transfer-signed.tx
$sandboxcli copyTo "trx-group-asa-transfer-signed.tx"
echo "Transfering one unit of AppASA with clerk"
${goalcli} clerk rawsend -f trx-group-asa-transfer-signed.tx 
rm -f *.tx
rm -f *.rej
rm -f awk
rm -f head
rm -f *.scratch
rm -f *.json
rm -f sed
;;
trxlist)
echo "listing transactions..."
curl "localhost:8980/v2/transactions?pretty"
;;

status)
echo "Getting node status from goal..."
${goalcli}  node status
;;
help)
echo "@emg110 demo for creating Algorand Standard Assets using linked stateful and stateless smart contracts"
echo "                "
echo "Step by step process flow:"
echo "                "
echo "1- ./appasa-goal.sh asc" 
echo "To create the stateful smart contract application and stateless smart contract escrow sccount" 
echo "                "
echo "2- ./appasa-goal.sh fund AMOUNT"
echo "To send funds (equal to AMOUNT) to escrow account from main account" 
echo "                "
echo "3- ./appasa-goal.sh link"
echo "To link stateful contract application with stateless contract escrow account" 
echo "                "
echo "4- ./appasa-goal.sh asa 'INDEX' or 'auto'"
echo "To generate standard asset with counter INDEX (e.g 0). set 'auto' to make everything automated" 
echo "                "
echo "5- ./appasa-goal.sh escrow"
echo "To check the assets generated in previous level under the escrow account info (Use this in next step if going to do it manual!)" 
echo "                "
echo "                "
echo "6- ./appasa-goal.sh axfer 'ID' or 'auto'"
echo "To transfer (receive) one unit of standard asset with ID (e.g 5). set 'auto' to make everything automated" 
echo "                "
echo " -------------------------------------------------               "
echo "Sandbox commands:"
echo "                "
echo "./appasa-goal.sh install" 
echo "Installs the sandbox instance" 
echo "                "
echo "./appasa-goal.sh reset"
echo "Resets the sandbox instance" 
echo "                "
echo "./appasa-goal.sh start"
echo "Starts the sandbox instance" 
echo "                "
echo "./appasa-goal.sh stop"
echo "Stops the sandbox instance" 
echo "                "
echo "--------------------------------------------------             "
echo "Other usefull commands:"
echo "                "
echo "./appasa-goal.sh main" 
echo "Show main account's info" 
echo "                "
echo "./appasa-goal.sh escrow"
echo "Show generated escrow account's info" 
echo "                "
echo "./appasa-goal.sh mainbal"
echo "Show main account's balance" 
echo "                "
echo "./appasa-goal.sh escrowbal"
echo "Show generated escrow account's balance" 
echo "                "

;;
*)
echo "Welcome To @emg110 (Hi, MG here!) demo for creating Algorand Standard Assets using linked stateful and stateless smart contracts"
echo "This repository contains educational (DO NOT USE IN PRODUCTION!) code and content in response to Algorand bounty on GitCoin: Stateful Smart Contract To Create Algorand Standard Asset (https://gitcoin.co/issue/algorandfoundation/grow-algorand/43/100025866)"
;;
esac