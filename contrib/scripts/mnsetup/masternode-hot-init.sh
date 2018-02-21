#!/bin/bash
NODE=$(hostname | sed "s/\..*//g")
COIN="gincoin"
BINDIR="gincoin-binaries"
SCRIPTDIR="gincoin-scripts"
BINURL="https://gincoin.io/gincoin-binaries.tar.gz"
CONFDIR=".gincoincore"
MN_CONFIRMATIONS=15
CLI=$BINDIR/${COIN}-cli
DAEMON=$BINDIR/${COIN}d
PORT=10111

export TERM=dumb
chsh -s /bin/bash

timeout() {
    time=$1

    # start the command in a subshell to avoid problem with pipes
    # (spawn accepts one command)
    command="/bin/sh -c \"$2\""

    expect -c "set echo \"-noecho\"; set timeout $time; spawn -noecho $command; expect timeout { exit 1 } eof { exit 0 }"

    if [ $? = 1 ] ; then
        echo "Timeout after ${time} seconds"
    fi
}

hr() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' ${1:--}
}

waitforsync() {
    STATUS=$($CLI mnsync status | jq ".AssetID")

    while [ ! "$STATUS" == "999" ]; do
        echo -ne "Waiting for client to sync (status $STATUS)..."
        sleep 10
        STATUS=$($CLI mnsync status | jq ".AssetID")
        echo -ne "\r"
    done
    echo ""
    echo "Sync complete."
}

if [[ "$(dpkg-query --show "jq" 2>&1)" = *"no packages"* ]]; then
    hr
    echo "Installing dependencies..."
    hr

    add-apt-repository ppa:bitcoin/bitcoin -y && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y && \
    apt-get autoremove -y && \
    apt-get install -y htop libboost-all-dev libzmq3-dev libdb4.8-dev libdb4.8++-dev libevent-dev libssl-doc zlib1g-dev fail2ban jq bc || exit 1

    hr
    echo "Rebooting MN server, launch script exactly the same in 30 sec."
    hr
    reboot
fi

if [[ "$(ufw status 2>&1)" = *"inactive"* ]]; then
    hr
    echo "Setting up firewall..."
    hr

    ufw default allow outgoing && \
        ufw default deny incoming && \
        ufw allow ssh/tcp && \
        ufw allow $PORT/tcp && \
        ufw logging on && \
        ufw --force enable || exit 1

    systemctl enable fail2ban && \
        systemctl start fail2ban || exit 1
fi

if [[ ! -d $BINDIR ]]; then
    hr
    echo "Loading files..."
    hr

    curl $BINURL --output $BINDIR.tar.gz && \
        tar -zxvf $BINDIR.tar.gz && \
        mkdir -p $CONFDIR && \
        mv $BINDIR/$COIN.conf $CONFDIR/ && \
        rm $BINDIR.tar.gz || exit 1
fi

IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [[ ! -z $(cat $CONFDIR/$COIN.conf | grep {IP}) ]]; then
    hr
    echo "Configuring IP..."
    hr

    echo "Setting public IP: $IP" && sed -i -e "s/{IP}/$IP/g" $CONFDIR/$COIN.conf || exit 1
fi

hr
echo "Starting GINcoin..."
hr

$CLI getinfo || $DAEMON -daemon
sleep 5

if [[ -z $(cat $CONFDIR/$COIN.conf | grep masternodeprivkey) ]]; then
    hr
    echo "Configuring masternode private key..."
    hr

    PRIVKEY=$($CLI masternode genkey) && \
        echo "masternode=1" >> $CONFDIR/$COIN.conf && \
        echo "masternodeprivkey=$PRIVKEY" >> $CONFDIR/$COIN.conf || exit 1

    $CLI stop
    sleep 5
    $DAEMON -daemon
    sleep 5
else
    PRIVKEY=$(cat $CONFDIR/$COIN.conf | grep masternodeprivkey | sed "s/masternodeprivkey=//")
fi

waitforsync

ADDRESS=""

if [[ "$($CLI masternode outputs | jq keys)" == "[]" ]]; then
    hr
    echo "Setting up the GIN masternode collateral"
    hr

    echo "Generating your MN GIN address"
    ADDRESS=$($CLI getnewaddress $NODE)
    echo "Address generated:"
    echo "  - ADDRESS: $ADDRESS"
    echo "  - PRIVATE KEY: $($CLI dumpprivkey $ADDRESS)"
    echo "Backup the private key somewhere safe, it gives complete access over your collateral (1000 GIN)"

    hr
    echo "Send exactly 1000 GIN (no more, no less) to the following address: $ADDRESS"

    TRID=$($CLI listtransactions | jq "last(.[] | select(.address==\"$ADDRESS\"))" | jq ".txid")

    while [ "$TRID" == "null" ]; do
        echo -ne "Waiting for your transaction to propagate..."
        sleep 5
        TRID=$($CLI listtransactions | jq "last(.[] | select(.address==\"$ADDRESS\"))" | jq ".txid")
        echo -ne "\r"
    done

    echo "Transaction propagated."

    CONFIRMATIONS=$($CLI listtransactions | jq "last(.[] | select(.address==\"$ADDRESS\"))" | jq ".confirmations")
    echo "Waiting for your transaction to get $MN_CONFIRMATIONS confirmations"
    echo "This may take about 30 minutes"

    while [ "$CONFIRMATIONS" -lt "$MN_CONFIRMATIONS" ]; do
        echo -ne "  ($CONFIRMATIONS/$MN_CONFIRMATIONS)...\r"
        sleep 5
        CONFIRMATIONS=$($CLI listtransactions | jq "last(.[] | select(.address==\"$ADDRESS\"))" | jq ".confirmations")
    done
    echo -ne '\n'

    echo "Transaction confirmed."
fi

if [[ "$($CLI masternode outputs | jq keys)" == "[]" ]]; then
    echo "Something went wrong with the automatic detection of your transaction. Please get in touch."
    exit 1
fi

TXID=$($CLI masternode outputs | jq keys | jq ".[0]" | sed "s/\"//g")
TXINDEX=$($CLI masternode outputs | jq ".[\"$TXID\"]" | sed "s/\"//g")

if [[ "$(cat $CONFDIR/masternode.conf | grep $NODE)" == "" ]]; then
    echo "$NODE $IP:$PORT $PRIVKEY $TXID $TXINDEX" > $CONFDIR/masternode.conf

    $CLI stop
    sleep 5
    $DAEMON -daemon
    sleep 5

    waitforsync

    $CLI masternode start-alias $NODE
fi

hr
echo "Rewards address"
hr
echo -ne "Enter a GINcoin address where to send the masternode rewards: "
read REWARD_ADDRESS

while [[ ! $REWARD_ADDRESS == G* ]]; do
    echo -ne "Invalid address, a valid GIN address starts with 'G'. Please enter it again: "
    read REWARD_ADDRESS
done

REWARD_ADDRESS="$(echo -e "${REWARD_ADDRESS}" | tr -d '[:space:]')"

echo $REWARD_ADDRESS > $CONFDIR/reward
echo "Rewards will be sent at $(cat $CONFDIR/reward) immediately as they become available (101 confirmations)"

#set up scripts

mkdir -p $SCRIPTDIR

cat <<EOT >> $SCRIPTDIR/check
#!/bin/bash
STATUS=\$(~/$CLI masternodelist | jq ".[\"$TXID-$TXINDEX\"]")

if [[ ! \$STATUS = *"ENABLED"* ]]; then
    echo "Starting masternode"
    ~/$CLI masternode start-alias $NODE
else
    echo "Masternode is \$STATUS"
fi
EOT

cat <<EOT >> $SCRIPTDIR/reward
#!/bin/bash
AMOUNT=\$(echo "\$(~/$CLI getbalance)-1000.01" | bc -l)
ADDRESS=\$(cat ~/$CONFDIR/reward)

if [[ "\$(echo "\$AMOUNT>0" | bc -l)" == "1" ]]; then
    echo "Sending \$AMOUNT to \$ADDRESS"
    ~/$CLI sendtoaddress \$ADDRESS \$AMOUNT
fi
EOT

cat <<EOT >> $SCRIPTDIR/update
#!/bin/bash
curl $BINURL --output $BINDIR.tar.gz && \
rm -rf $BINDIR && \
tar -zxvf $BINDIR.tar.gz && \
rm $BINDIR.tar.gz && \
$CLI stop && \
sleep 5 && \
$DAEMON -daemon
EOT

chmod +x $SCRIPTDIR/*

#set up crons
touch cronfile
echo "* * * * * /root/$SCRIPTDIR/check >> check.log" >> cronfile
echo "* * * * * /root/$SCRIPTDIR/reward >> reward.log" >> cronfile
crontab cronfile
rm cronfile

#restore firewall limit
ufw limit ssh/tcp

#done

echo "Your masternode is up and running, rewards should start coming within the next 24h"
exit