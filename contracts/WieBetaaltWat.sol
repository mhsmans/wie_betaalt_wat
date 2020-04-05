pragma solidity >= 0.5.0 < 0.7.0;

contract WieBetaaltWat {

    struct Member {
      string name;
      address walletAddress;
      int balance;
    }

    struct Expense {
      string title;
      uint amount;
      address payer;
    }

    mapping(address => Member) public members;
    Expense[] public expenses;
    bool groupClosed;
    address payable[] internal memberAddresses;

    constructor() public {
        groupClosed = false;
    }

    // Add new member to group
    function addMember(string calldata name) external {
        require(
            msg.sender != members[msg.sender].walletAddress,
            "Member can have only one address"
        );
        require(!groupClosed, "Group is closed");
        Member memory member = Member({name: name, walletAddress: msg.sender, balance: 0});
        members[msg.sender] = member;
        memberAddresses.push(msg.sender);
    }

    // Create expense, amount is stored in Szabo (factor 12). Gwei is used because 'ether'(factor 18) will cause decimals to exist. The smalles
    // factor, wei (factor 0), is not used because storing very large numbers causes exceptions.
    function createExpense(string calldata title, uint amount) external {
        require(amount > 0, "An expense needs to have an amount above 0");
        require(msg.sender == members[msg.sender].walletAddress, "Sender wallet address must exist in members mapping");
        require(groupClosed, "Group must be closed to start creating expenses");

        Expense memory expense = Expense(title, amount, msg.sender);
        expenses.push(expense);

        uint pricePerMember = amount / memberAddresses.length;

        // Update sender balance
        members[msg.sender].balance += int(pricePerMember * (memberAddresses.length - 1));

        for(uint i = 0; i < memberAddresses.length; i++) {
            // For every member apart from expense creator, update balance
            if(members[memberAddresses[i]].walletAddress != msg.sender) {
                updateBalance(
                    members[memberAddresses[i]].balance - int(pricePerMember),
                    members[memberAddresses[i]].walletAddress);
            }
        }
    }

    // Store ether inside contract
    function deposit() external payable {
        require(msg.sender == members[msg.sender].walletAddress, "Sender address must exist in members mapping");
        require(members[msg.sender].balance < 0, "Sender must owe to group");
        require(msg.value > 0, "There must be an amount larger than 0");

        // Balance is converted from Szabo (factor 12) to wei (factor 0)
        int i = (members[msg.sender].balance * 10**12);
        int j = int(msg.value) + i;

        if(j == 0) {
            // Sender pays his debts exactly
            updateBalance(0, msg.sender);
        } else if (j > 0) {
            // Sender pays too much
            updateBalance(0, msg.sender);
            msg.sender.transfer(uint(j));
        } else {
            // Sender pays part of his debts, i converted from wei (factor 0) to Szabo (factor 12)
            updateBalance((j / 10**12), msg.sender);
        }
    }

    // Pay members with positive balances.
    function payMembers() external {
        require(msg.sender == members[msg.sender].walletAddress, "Sender address must exist in members mapping");
        // All members must have a positive balance or a balance equal to zero
        for(uint i = 0; i < memberAddresses.length; i++) {
            if(members[memberAddresses[i]].balance > 0) {
                // Pay member and set balance to 0
                int balance = members[memberAddresses[i]].balance;
                members[memberAddresses[i]].balance = 0;
                memberAddresses[i].transfer(uint(balance * 10**12));
            }
        }
    }

    function closeGroup() external {
        require(msg.sender == members[msg.sender].walletAddress, "Sender wallet address must exist in members mapping");
        groupClosed = true;
    }

    // Open group only when all member balances are equal to 0
    function openGroup() external {
        require(msg.sender == members[msg.sender].walletAddress, "Sender wallet address must exist in members mapping");
        bool balancesEqualZero = true;

        for(uint i = 0; i < memberAddresses.length; i++) {
            if(members[memberAddresses[i]].balance != 0) {
                balancesEqualZero = false;
            }
        }

        if (balancesEqualZero) {
            groupClosed = false;
        }
    }

    function updateBalance(int updatedBalance, address memberAddress) internal {
        members[memberAddress].balance = updatedBalance;
    }

    function getPersonalBalance() external view returns(string memory, int) {
        return (members[msg.sender].name, members[msg.sender].balance);
    }

    function getContractBalance() external view returns(uint) {
        address cAddress = address(this);
        // Show contract balance in szabo (error: number can only safely store up to 53 bits)
        return cAddress.balance / 10**12;
    }

    function getGroupStatus() external view returns(string memory) {
        if(groupClosed) {
            return "Group is closed";
        } else {
            return "Group is open";
        }
    }
}
