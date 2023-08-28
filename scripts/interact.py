import brownie
from brownie import Lottery, network, config
from time import sleep
from scripts.helpful_scripts import *

network.priority_fee(config["priority_fee"])

# This is a small script that allows you to manage the last lottery deployed through your command line


def main():
    addr = Lottery[-1]
    account = get_account("Developing-account")
    exit = False
    tx = ""
    print(f"{addr.address}")

    while not exit:
        cmd = int(
            input(
                "What do you like to do?\n1. Start Lottery\n2. Enter Lottery\n3. End Lottery\n4. Reset Lottery\n5. Check winner\n6. Withdraw LINK\n7. Fund with LINK\n8. Exit\n\nYour Command: "
            )
        )
        try:
            if cmd == 1:
                print("Starting Lottery...\n")
                tx = addr.startLottery({"from": account})
                tx.wait(2)
            elif cmd == 2:
                print("\nGetting you into play...\n")
                tx = addr.enterLottery(
                    {"from": account, "value": addr.getEntranceFee()}
                )
                tx.wait(2)
            elif cmd == 3:
                print("\nEnding Lottery and extracting the winner...\n")
                tx = addr.endLottery({"from": account})
                tx.wait(2)
            elif cmd == 4:
                print("Resetting the Lottery...\n")
                tx = addr.resetLottery(addr.getPlayersNumber(), {"from": account})
                tx.wait(2)
            elif cmd == 5:
                print(f"The last winner is {addr.recent_winner()}!\n")
            elif cmd == 6:
                print("Withdrawing LINK tokens...\n")
                tx = addr.withdrawLink({"from": account})
                tx.wait(2)
            elif cmd == 7:
                print("Funding the contract with some LINK...\n")
                fund_with_link(addr, account)
            elif cmd == 8:
                exit = True
            else:
                print("\nCommand not found!\n")
        except:
            print("Transaction Reverted!\n")
