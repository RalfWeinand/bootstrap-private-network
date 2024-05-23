# Instructions for Building Savanna Network

## Environment

Many linux OS will work, these instructions have been validated on `ubuntu 22.04`.

### Prerequisites
Apt-get and install the following
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/main/AntelopeDocker#L3-L20
You will also need to install the following python packages
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/main/AntelopeDocker#L21

## Build Antelope Software
You will need to build the following Antelope software from source, using the specified git branches. The software should be built in the following order to satisfy dependancies `Spring`, followed by `CDT`, followed by `Reference Contracts`.

These Git Commit Hashes or Tags are current to the following date.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/docker-build-image.sh#L17

### Branches
- Spring: branch `release/1.0-beta1` repo `AntelopeIO/spring`
- CDT: branch `release/4.1` repo `AntelopeIO/cdt`
- Reference Contracts: branch `main` repo `AntelopeIO/reference-contracts`

[Full Instructions for Building Spring](https://github.com/AntelopeIO/spring?tab=readme-ov-file#build-and-install-from-source), [Full Instructions for Building CDT](https://github.com/antelopeio/cdt?tab=readme-ov-file#building-from-source) or you can review the [Reference Script to Build Spring and CDT](/bin/build_antelope_software.sh).
[Full Instructions for Building Reference Contracts](https://github.com/antelopeio/reference-contracts?tab=readme-ov-file#building) or you can review [Reference Script to Build Contracts](/bin/build_eos_contracts.sh).

## Install Antelope Software
Now that the binaries are build you need to add CDT and Spring to your path or install them into well know locations. The [Reference Install Script](/bin/install_antelope_software.sh) must be run as root and demonstrates one way to install the software.

Note, the `Reference Contracts` are install later during the initialization of the EOS blockchain.

## Initialize Block Chain
Before we can start up our multi-producer blockchain a few preparations are needed.
#### `Create New Key Pair`
We will create a new key pair for the root user of the blockchain. You will use the Public Key often in the setup, so please save these keys for use later. You will see a `PublicKey` and `PrivateKey` printed to the console using the following command.
`cleos create key --to-console`
We create three additional key pairs for each of our producers. Here the producers are named `bpa`, `bpb`, `bpc`.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L72-L80
#### `Create Genesis File`
Take the reference [Genesis File](/config/genesis.json) and replace the value for `Initial Key` with the `PublicKey` generated previously. Replace the the value for `Initial Timestamp` with now. In linux you can get the correct format for the date with the following command `date +%FT%T.%3N`.
#### `Create Shared Config`
We will create a shared config file for the common configuration values. Configuration here is only for preview development purposes and should not be used as a reference production config. Copy [config.ini](/config/config.ini) to your filesystem. Additional configuration values will be added on the command line.
#### `Create Log and Data Dir`
You will need to create three data directories, one for each instance of nodeos you will run. You will need a place for log files as well. For example:
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L87-L90
#### `Create Wallet`
You need to create and import the root private key into a wallet. This will allow you to run initialization commands on the blockchain. In the example below we have a named wallet and we save the wallet password to a file.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L72
Then import your Root `PrivateKey` adding it to the wallet. We do not need to import our keys for each of the block producers.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L97-L98
If you have already created a wallet you may need to unlock your wallet using your password
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/open_wallet.sh#L19
#### `Initialization Data`
Taking everything we have prepared we will now start a `nodoes` instance. We will be issuing commands while nodes is running so run this command in the background, or be prepared to open multiple terminals on your host. You'll notice we specified the
- genesis file
- config file
- data directory for first instance
- public and private key from our very first step
It is very important to include the option `--enable-stale-production`, we will need that to bootstrap our network.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L102-L109

## Creating Contracts and Accounts
One the node is running we need to run two scripts to add accounts and contracts. We break down this process into three steps.
- boot actions
- create accounts
- block producer setup

#### `Boot Actions`
[boot_actions.sh](/bin/boot_actions.sh) is the reference script. You pass in the following values, reference contracts is your locale git repository where you build the reference contracts software.

- 127.0.0.1:8888
- $DIR/reference-contracts/build/contracts
- PublicKey

This script creates the system accounts.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/boot_actions.sh#L15-L24

We create 380,000,000 EOS tokens.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/05d5b9c9806dbcd0a593a4108386b1e6f1a4dc24/bin/boot_actions.sh#L26-L28

Below we activate the protocols needed to support Savanna and create the `boot`, and `system` contracts.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/boot_actions.sh#L32-L80

#### `Create Accounts`

[create_accounts.sh](/bin/create_accounts.sh) takes two arguments
- 127.0.0.1:8888
- $WALLET_DIR

Next we create 3 producer accounts, one for each of our nodes. After creating the keys, we create the accounts, allocate EOS, and add some resources.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/05d5b9c9806dbcd0a593a4108386b1e6f1a4dc24/bin/create_accounts.sh#L16-L20

We create 26 users accounts. These accounts will stake resources and vote for producers. Same commands we used to create the producers. The only difference is funding amounts.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/05d5b9c9806dbcd0a593a4108386b1e6f1a4dc24/bin/create_accounts.sh#L33-L37

#### `Block Producer Setup`
[block_producer_setup](/bin/block_producer_setup.sh) is the reference script. You pass in the following values

- 127.0.0.1:8888
- $WALLET_DIR

This script create registers new block producers and users vote for producers.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/05d5b9c9806dbcd0a593a4108386b1e6f1a4dc24/bin/block_producer_setup.sh#L16
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/05d5b9c9806dbcd0a593a4108386b1e6f1a4dc24/bin/block_producer_setup.sh#L28

#### `Shutdown`
Now that we have initialized our first instance we need to shut it down and restart. Find the pid and send `kill -15 $pid` to terminate the instance.

## Create Network
Now we start our three nodes peer'd to each other. The Second and Third nodes will start from genesis and pull updates from the First node. The First nodes has already been initialized and it will start from its existing state. Soon each node will have the same information and the same head block number.

In the examples below we user different `PublicKey` and `PrivateKey` for each producer.

#### `Node One`
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L134-L143
#### `Node Two`
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L152-L161
#### `Node Three`
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L180-L189

## Check Blocks Behind
Here you can check the Head Block Number and Last Irreversible Block and see there are far apart. `cleos get info`

## Activate Savanna
For the last step we will activate the new Savanna algorithm.

#### `Generate Finalizer Keys`
We need to generate the new BLS finalizer keys and add them to our configuration file. Each producer needs to generate a finalizer key. We have three nodes and that requires calling `spring-util bls create key` three times.
`spring-util bls create key --to-console`
Save the output from the command. The public and private keys will be added as `signiture-provider` lines to `config.ini`. This configuration file is shared across all three instances and each instance will have all three lines.
- BLS Public keys start with `PUB_BLS_`
- BLS Private keys start with `PVT_BLS_`
- BLS Proof of possession signatures start with `SIG_BLS_`

```
echo "signature-provider = ""${NODE_ONE_PUBLIC_KEY}""=KEY:""${NODE_ONE_PRIVATE_KEY}" >> config.ini
echo "signature-provider = ""${NODE_TWO_PUBLIC_KEY}""=KEY:""${NODE_TWO_PRIVATE_KEY}" >> config.ini
echo "signature-provider = ""${NODE_THREE_PUBLIC_KEY}""=KEY:""${NODE_THREE_PRIVATE_KEY}" >> config.ini
```

#### `Apply New Configuration`
Now that the configuration is in the shared `config.ini` we need to stop and re-start all three nodes to load the new configuration. Find the pid and send `kill -15 $pid` to terminate all three instances. Now start up the nodes. Here are examples from our reference development script. The `signature-provider` argument on the command line is the [EOS Root Key Pair](/doc/step-by-step.md#create-new-key-pair) we created earlier, and it is still needed for this restart step.

https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L134-L143

https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L163-L172

https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/3294441405fe45cfeb417e606fbf2cd6d6f75a09/bin/finality_test_network.sh#L191-L200

#### `Register Finalizer Key`
The [activate_savanna.sh](/bin/activate_savanna.sh) script registers the finalizer keys. In this example we register one for each producer.
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/05d5b9c9806dbcd0a593a4108386b1e6f1a4dc24/bin/activate_savanna.sh#L23-L27

Here is an example using the regfinkey action. Note the permission used is the block producer's.
```
cleos --url $ENDPOINT push action eosio regfinkey '{"finalizer_name":"NewBlockProducer", \
      "finalizer_key":"PUB_BLS_v8-ZaaZZ5ZZaZ5ZaZZZZaa5aZaZaaZZa5aZZ5aZaZ5aaZZa5a-ZaZZ555Z55aZZZ5aZaZZaZaaZ5aZ55ZaZZaaaaaaZa5Z-5aa5aaaaZaaZ5Zaaaaa5ZaaZZaaa5ZaZZZaZa5a", \
      "proof_of_possession":"SIG_BLS_aa5Z-aZZZ5aaaZZZ5ZaaaZ5a-aZaa_aaZZ5aaa55aZa-ZaZZaZZZ5ZZZaaZZZ5ZZZZ-aaZ_55ZZZ5Z5a5ZZaaa5aZZ5aZaaZ5aa5ZaaZ-ZZZZa5ZaaaZZa5aaZZZZaaZ5ZZZZZa5ZZZ5Z55a5ZZZ5aaZa5Z5ZZ5Z5-aaZZZZZ-ZZZaZZ5a5aaZZZaZa5ZZ5ZaZaaaZaZaa5aaaaaaa5aZZaaZ5aZ5ZZ5aaaZZaaaaaZZaZa55ZaZaaaaaaZaZZZZZa5aZa"}' \
      -p NewBlockProducer
```

#### `Activate Savanna`
The final step is to activate savanna. This is done with a action that takes no arguments. The permission required is `eosio@active`
https://github.com/eosnetworkfoundation/bootstrap-private-network/blob/05d5b9c9806dbcd0a593a4108386b1e6f1a4dc24/bin/activate_savanna.sh#L35

#### `Verify Faster Finality`
Here you can check the Head Block Number and Last Irreversible Block and see they are three apart. `cleos get info`

In addition you can check your logs for the following strings, the will provide information on the exact block where the transition will/does occur.
- `Transitioning to savanna`
- `Transition to instant finality`


Congratulations you are running a Private EOS network with the new, faster finality, Savanna algorithm.
