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
#set -x
set -e
bashuppercli="../"
goalcli="../sandbox/sandbox goal"
tealdbgcli="../sandbox/sandbox tealdbg"
sandboxcli="../sandbox/sandbox"
ACC=$(${goalcli} account list|awk '{ print $3 }'|tail -1)
APPROVAL_PROG="appasa-approval-prog.teal"
CLEAR_PROG="appasa-clear-prog.teal"
ESCROW_PROG="appasa-escrow-prog.teal"
case $1 in
asc)
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
echo "Application ID:$APP_ID_TRIM"
echo "Main account:$MAIN_ACC"
${goalcli} app call --app-id ${APP_ID_TRIM} --app-arg "str:escrow_set" --app-arg "addr:${ESCROW_ACC_TRIMM}" -f ${MAIN_ACC}
${goalcli} app read --app-id ${APP_ID_TRIM} --guess-format --global --from ${MAIN_ACC}
;;
asa)
echo "Generating Standard Asset..."
MAIN_ACC=$(<appasa-main-account.txt)
ESCROW_ACC=$(cat "appasa-escrow-account.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
ESCROW_ACC_TRIM="${ESCROW_ACC//$'\r'/ }"
APP_ID=$(cat "appasa-id.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
APP_ID_TRIM="${APP_ID//$'\r'/ }"
ESCROW_PROG_SND="appasa-escrow-prog-snd.teal"
$sandboxcli copyTo "$ESCROW_PROG_SND"
echo "Escrow account: $ESCROW_ACC_TRIM"
echo "Application ID:$APP_ID_TRIM"
echo "The asset name (AppASA-x) counter (x): $2"
${goalcli} app call --app-id ${APP_ID_TRIM} --app-arg "str:asa_gen" -f ${MAIN_ACC} -o trx-call-app-unsigned.tx
$sandboxcli copyFrom "trx-call-app-unsigned.tx"
${goalcli} asset create --creator ${ESCROW_ACC_TRIM} --name "AppASA-${2}" --total 99999999 --decimals 0 -o trx-create-asa-unsigned.tx
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
rm -f *.trt
rm -f *.json
rm -f sed
;;
dryrun)
echo "Dry running signed transaction group"
${goalcli} clerk dryrun -t trx-group-asa-signed.tx --dryrun-dump -o trx-group-asa-signed-dryrun.json
$sandboxcli copyFrom "trx-group-asa-signed-dryrun.json"
;;
axfer)
echo "Receiving Standard Asset..."
MAIN_ACC=$(<appasa-main-account.txt)
ESCROW_ACC=$(cat "appasa-escrow-account.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
ESCROW_ACC_TRIM="${ESCROW_ACC//$'\r'/ }"
APP_ID=$(cat "appasa-id.txt" | head -n 1 | awk -v awk_var='' '{ gsub(" ", awk_var); print}')
APP_ID_TRIM="${APP_ID//$'\r'/ }"
echo "Escrow account: $ESCROW_ACC_TRIM"
echo "Application ID:$APP_ID_TRIM"
echo "The asset ID from which 1 (one) unit will be transfered to main account: $2"
#ASSET_INDEX=$(${goalcli} account info -a ${ESCROW_ACC_TRIM} | grep ID | head -n 1 | awk '{ print $2 }')
#echo ${ASSET_INDEX%?}
ESCROW_PROG_SND="appasa-escrow-prog-snd.teal"
${goalcli} asset send --assetid ${2} -f ${MAIN_ACC} -t ${MAIN_ACC} -a 0
${goalcli} app call --app-id ${APP_ID_TRIM} --app-arg "str:asa-xfer" -f ${MAIN_ACC} -o trx-get-asa-unsigned.tx
$sandboxcli copyFrom "trx-get-asa-unsigned.tx"
${goalcli} asset send --assetid ${2} -f ${ESCROW_ACC_TRIM} -t ${MAIN_ACC} -a 1 -o trx-send-asa-unsigned.tx
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
rm -f *.trt
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
echo "Welcome To @emg110 demo for creating Algorand Standard Assets using linked stateful and stateless smart contracts"
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
echo "4- ./appasa-goal.sh asa INDEX"
echo "To generate standard asset with counter INDEX (e.g 0)" 
echo "                "
echo "5- ./appasa-goal.sh axfer ID"
echo "To transfer (receive) one unit of standard asset with  ID (e.g 5)" 
echo "                "
echo "                "
;;
*)
echo "Welcome To @emg110 demo for creating Algorand Standard Assets using linked stateful and stateless smart contracts"
echo "This repository contains educational code & content in response to Algorand bounty on GitCoin: Stateful Smart Contract To Create Algorand Standard Asset (https://gitcoin.co/issue/algorandfoundation/grow-algorand/43/100025866)"
;;
esac