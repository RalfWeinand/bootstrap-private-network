#!/usr/bin/env bash

####
# Once antelope software is build and installed
# script to manage private network
# CREATE new network with 3 nodes
# CLEAN out data from previous network
# STOP all nodes on network
# START 3 node network
####

COMMAND=${1:-"NA"}
ROOT_DIR="/bigata1/savanna"
LOG_DIR="/bigata1/log"
WALLET_DIR=${HOME}/eosio-wallet
CONTRACT_DIR="/local/eosnetworkfoundation/repos/reference-contracts/build/contracts"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
GENESIS_FILE="/local/eosnetworkfoundation/repos/bootstrap-private-network/config/genesis.json"
CONFIG_FILE="/local/eosnetworkfoundation/repos/bootstrap-private-network/config/config.ini"

echo "STARTING COMMAND ${COMMAND}"

if [ "$COMMAND" == "NA" ]; then
  echo "usage: finality_test_network.sh [CREATE|START|CLEAN|STOP]"
  exit 1
fi

if [ "$COMMAND" == "CLEAN" ]; then
    for d in nodeos-one nodeos-two nodeos-three; do
        [ -f "$ROOT_DIR"/${d}/data/blocks/blocks.log ] && rm -f "$ROOT_DIR"/${d}/data/blocks/blocks.log
        [ -f "$ROOT_DIR"/${d}/data/blocks/blocks.index ] && rm -f "$ROOT_DIR"/${d}/data/blocks/blocks.index
        [ -f "$ROOT_DIR"/${d}/data/state/shared_memory.bin ] && rm -f "$ROOT_DIR"/${d}/data/state/shared_memory.bin
        [ -f "$ROOT_DIR"/${d}/data/state/code_cache.bin ] && rm -f "$ROOT_DIR"/${d}/data/state/code_cache.bin
        [ -f "$ROOT_DIR"/${d}/data/blocks/reversible/fork_db.dat ] && rm -f "$ROOT_DIR"/${d}/data/blocks/reversible/fork_db.dat
    done
fi

if [ "$COMMAND" == "CREATE" ] || [ "$COMMAND" == "START" ]; then
  # get config information
  NODEOS_ONE_PORT=8888
  ENDPOINT="http://127.0.0.1:${NODEOS_ONE_PORT}"

  # create private key
  [ ! -d "$WALLET_DIR" ] && mkdir -p "$WALLET_DIR"
  [ ! -f "$WALLET_DIR"/finality-test-network.keys ] && cleos create key --to-console > "$WALLET_DIR"/finality-test-network.keys
  # head because we want the first match; they may be multiple keys
  EOS_ROOT_PRIVATE_KEY=$(grep Private "${WALLET_DIR}"/finality-test-network.keys | head -1 | cut -d: -f2 | sed 's/ //g')
  EOS_ROOT_PUBLIC_KEY=$(grep Public "${WALLET_DIR}"/finality-test-network.keys | head -1 | cut -d: -f2 | sed 's/ //g')

  # create initialize genesis file; create directories; copy cofigs into place
  if [ "$COMMAND" == "CREATE" ]; then
    NOW=$(date +%FT%T.%3N)
    sed "s/\"initial_key\": \".*\",/\"initial_key\": \"${EOS_ROOT_PUBLIC_KEY}\",/" $GENESIS_FILE > /tmp/genesis.json
    sed "s/\"initial_timestamp\": \".*\",/\"initial_timestamp\": \"${NOW}\",/" /tmp/genesis.json > ${ROOT_DIR}/genesis.json
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$ROOT_DIR"/nodeos-one/data ] && mkdir -p "$ROOT_DIR"/nodeos-one/data
    [ ! -d "$ROOT_DIR"/nodeos-two/data ] && mkdir -p "$ROOT_DIR"/nodeos-two/data
    [ ! -d "$ROOT_DIR"/nodeos-three/data ] && mkdir -p "$ROOT_DIR"/nodeos-three/data
    # setup common config, shared by all nodoes instances
    cp "${CONFIG_FILE}" ${ROOT_DIR}/config.ini
  fi

  # setup wallet
  "$SCRIPT_DIR"/open_wallet.sh "$WALLET_DIR"
  # Import Root Private Key
  cleos wallet import --name finality-test-network-wallet --private-key $EOS_ROOT_PRIVATE_KEY

  # start nodeos one always allow stale production
  if [ "$COMMAND" == "CREATE" ]; then
    nodeos --genesis-json ${ROOT_DIR}/genesis.json --agent-name "Finality Test Node One" \
      --http-server-address 0.0.0.0:${NODEOS_ONE_PORT} \
      --p2p-listen-endpoint 0.0.0.0:1444 \
      --enable-stale-production \
      --producer-name eosio \
      --signature-provider ${EOS_ROOT_PUBLIC_KEY}=KEY:${EOS_ROOT_PRIVATE_KEY} \
      --config "$ROOT_DIR"/config.ini \
      --data-dir "$ROOT_DIR"/nodeos-one/data > $LOG_DIR/nodeos-one.log 2>&1 &
    NODEOS_ONE_PID=$!

    # create accounts, activate protocols, create tokens, set system contracts
    sleep 1
    "$SCRIPT_DIR"/boot_actions.sh "$ENDPOINT" "$CONTRACT_DIR" "$EOS_ROOT_PUBLIC_KEY"
    "$SCRIPT_DIR"/block_producer_schedule.sh "$ENDPOINT" "$EOS_ROOT_PUBLIC_KEY"
    sleep 1
    kill -15 $NODEOS_ONE_PID
    # wait for shutdown
    sleep 15
  fi

  # if CREATE we bootstraped the node and killed it
  # if START we have no node running
  # either way we need to start Node One
  nodeos --agent-name "Finality Test Node One" \
    --http-server-address 0.0.0.0:${NODEOS_ONE_PORT} \
    --p2p-listen-endpoint 0.0.0.0:1444 \
    --enable-stale-production \
    --producer-name bpa \
    --signature-provider ${EOS_ROOT_PUBLIC_KEY}=KEY:${EOS_ROOT_PRIVATE_KEY} \
    --config "$ROOT_DIR"/config.ini \
    --data-dir "$ROOT_DIR"/nodeos-one/data \
    --p2p-peer-address 127.0.0.1:2444 \
    --p2p-peer-address 127.0.0.1:3444 > $LOG_DIR/nodeos-one.log 2>&1 &

  # start nodeos two
  sleep 5
  if [ "$COMMAND" == "CREATE" ]; then
    nodeos --genesis-json ${ROOT_DIR}/genesis.json --agent-name "Finality Test Node Two" \
      --http-server-address 0.0.0.0:6888 \
      --p2p-listen-endpoint 0.0.0.0:2444 \
      --producer-name bpb \
      --signature-provider ${EOS_ROOT_PUBLIC_KEY}=KEY:${EOS_ROOT_PRIVATE_KEY} \
      --config "$ROOT_DIR"/config.ini \
      --data-dir "$ROOT_DIR"/nodeos-two/data \
      --p2p-peer-address 127.0.0.1:1444 \
      --p2p-peer-address 127.0.0.1:3444 > $LOG_DIR/nodeos-two.log 2>&1 &
  else
    nodeos --agent-name "Finality Test Node Two" \
      --http-server-address 0.0.0.0:6888 \
      --p2p-listen-endpoint 0.0.0.0:2444 \
      --producer-name bpb \
      --signature-provider ${EOS_ROOT_PUBLIC_KEY}=KEY:${EOS_ROOT_PRIVATE_KEY} \
      --config "$ROOT_DIR"/config.ini \
      --data-dir "$ROOT_DIR"/nodeos-two/data \
      --p2p-peer-address 127.0.0.1:1444 \
      --p2p-peer-address 127.0.0.1:3444 > $LOG_DIR/nodeos-two.log 2>&1 &
  fi
  sleep 10

  if [ "$COMMAND" == "CREATE" ]; then
    nodeos --genesis-json ${ROOT_DIR}/genesis.json --agent-name "Finality Test Node Three" \
      --http-server-address 0.0.0.0:7888 \
      --p2p-listen-endpoint 0.0.0.0:3444 \
      --producer-name bpc \
      --signature-provider ${EOS_ROOT_PUBLIC_KEY}=KEY:${EOS_ROOT_PRIVATE_KEY} \
      --config "$ROOT_DIR"/config.ini \
      --data-dir "$ROOT_DIR"/nodeos-three/data \
      --p2p-peer-address 127.0.0.1:1444 \
      --p2p-peer-address 127.0.0.1:2444 > $LOG_DIR/nodeos-three.log 2>&1 &
  else
    nodeos --agent-name "Finality Test Node Three" \
      --http-server-address 0.0.0.0:7888 \
      --p2p-listen-endpoint 0.0.0.0:3444 \
      --producer-name bpc \
      --signature-provider ${EOS_ROOT_PUBLIC_KEY}=KEY:${EOS_ROOT_PRIVATE_KEY} \
      --config "$ROOT_DIR"/config.ini \
      --data-dir "$ROOT_DIR"/nodeos-three/data \
      --p2p-peer-address 127.0.0.1:1444 \
      --p2p-peer-address 127.0.0.1:2444 > $LOG_DIR/nodeos-three.log 2>&1 &
  fi
fi

if [ "$COMMAND" == "STOP" ]; then
  MY_ID=$(id -u)
  for p in $(ps -u $MY_ID | grep nodeos | sed -e 's/^[[:space:]]*//' | cut -d" " -f1); do
    echo $p && kill -15 $p
  done
fi

echo "COMPLETED COMMAND ${COMMAND}"
