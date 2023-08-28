from brownie import (
    network,
    accounts,
    config,
    interface,
    Contract,
)
import time

network.priority_fee(config["priority_fee"])

# Those are helpful_scripts to check if the contract is verifiable (set in the brownie config file),
# to get an account and to fund a contarct with link tokens.


def is_verifiable_contract() -> bool:
    return config["networks"][network.show_active()].get("verify", False)


def get_account(id=None):
    if id:
        return accounts.load(id)
    return accounts.add(config["wallets"]["from_key"])


def fund_with_link(contract_address, account, amount=5000000000000000000):
    link_token = config["networks"][network.show_active()]["link_token"]
    tx = interface.LinkTokenInterface(link_token).transfer(
        contract_address, amount, {"from": account}
    )
    tx.wait(2)
    print("Funded {}".format(contract_address))
    return tx
