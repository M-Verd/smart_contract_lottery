from brownie import Lottery, network, config
from time import sleep
from scripts.helpful_scripts import *

# This is the script that is used to deploy the Lottery contract in a safe and precise way.
# It works on Sepolia testnet only.

network.priority_fee(config["priority_fee"])


def deployLottery(account):
    active_network = network.show_active()

    ret_addr = Lottery.deploy(
        config["networks"][active_network]["eth_usd_price_feed"],
        config["networks"][active_network]["link_token"],
        config["networks"][active_network]["vrf_wrapper"],
        {"from": account},
        publish_source=is_verifiable_contract(),
    )
    fund_with_link(ret_addr, account)
    return ret_addr


def main():
    account = get_account(id="Developing-account")
    addr = deployLottery(account)
    print(f"\nEntrance Fee is {addr.getEntranceFee()} Wei")
    print(f"Entrance Fee is {addr.getEntranceFeeInUSD() / 10**8} $\n")
