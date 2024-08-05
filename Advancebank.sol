// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleBank {
    struct Account {
        string name;
        address accountAddress;
        uint256 accountNumber;
        uint256 balance;
        uint256 fixedDeposit;
        uint256 depositTimestamp;
        bool exists;
    }

    mapping(address => Account) public accounts;
    mapping(address => uint256) public loans;

    // Constants for interest rates
    uint256 constant FIXED_DEPOSIT_INTEREST_RATE = 10; // 10% per year
    uint256 constant LOAN_INTEREST_RATE = 12; // 12% per year

    // Higher precision for fractional calculations
    uint256 constant SCALE = 1e18; // Scale factor for fractional precision

    // Assume 1 year is approximately 365.25 days
    uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60 + 60 * 60 * 24; // Approx 31,557,600 seconds

    modifier onlyRegistered() {
        require(accounts[msg.sender].exists, "Account not registered");
        _;
    }

    function createAccount(string memory name, uint256 accountNumber) public {
        require(!accounts[msg.sender].exists, "Account already exists");
        accounts[msg.sender] = Account({
            name: name,
            accountAddress: msg.sender,
            accountNumber: accountNumber,
            balance: 0,
            fixedDeposit: 0,
            depositTimestamp: block.timestamp,
            exists: true
        });
    }

    function deposit() public payable onlyRegistered {
        accounts[msg.sender].balance += msg.value;
    }

    function withdraw(uint256 amount) public onlyRegistered {
        require(accounts[msg.sender].balance >= amount, "Insufficient balance");
        payable(msg.sender).transfer(amount);
        accounts[msg.sender].balance -= amount;
    }

    function depositFixed() public payable onlyRegistered {
        require(msg.value > 0, "Deposit amount should be greater than 0");
        
        // Apply interest before adding new deposit
        uint256 interest = calculateFixedDepositInterest(msg.sender);
        accounts[msg.sender].fixedDeposit += msg.value + interest;
        accounts[msg.sender].depositTimestamp = block.timestamp;
    }

    function withdrawFixed() public onlyRegistered {
        uint256 totalAmount = accounts[msg.sender].fixedDeposit;
        require(totalAmount > 0, "No fixed deposit found");

        // Apply interest before withdrawing
        uint256 interest = calculateFixedDepositInterest(msg.sender);
        totalAmount += interest;
        
        payable(msg.sender).transfer(totalAmount);
        accounts[msg.sender].fixedDeposit = 0;
    }

    function applyForLoan(uint256 amount) public onlyRegistered {
        require(amount > 0, "Loan amount should be greater than 0");
        loans[msg.sender] += amount;
        payable(msg.sender).transfer(amount);
    }

    event LoanRepaid(address indexed borrower, uint256 amountRepaid);

    function repayLoan() public payable onlyRegistered {
        uint256 loanAmount = loans[msg.sender];
        require(msg.value >= loanAmount, "Insufficient amount to repay loan");

        // Apply interest before repaying the loan
        uint256 totalAmount = loanAmount + calculateLoanInterest(msg.sender);

        require(msg.value >= totalAmount, "Insufficient amount to repay loan with interest");

        // Repay the loan and interest
        loans[msg.sender] = 0;

        // Refund any excess amount sent by the user
        if (msg.value > totalAmount) {
            payable(msg.sender).transfer(msg.value - totalAmount);
        }
        
        emit LoanRepaid(msg.sender, totalAmount);
    }

    function transfer(address to, uint256 amount) public onlyRegistered {
        require(accounts[msg.sender].balance >= amount, "Insufficient balance");
        require(accounts[to].exists, "Recipient not registered");
        accounts[msg.sender].balance -= amount;
        accounts[to].balance += amount;
    }

    function calculateFixedDepositInterest(address accountAddress) public view returns (uint256) {
        Account storage account = accounts[accountAddress];
        uint256 elapsedTime = block.timestamp - account.depositTimestamp;
        uint256 yearsElapsed = elapsedTime * SCALE / SECONDS_PER_YEAR;
        return (account.fixedDeposit * FIXED_DEPOSIT_INTEREST_RATE * yearsElapsed) / (100 * SCALE);
    }

    function calculateLoanInterest(address accountAddress) public view returns (uint256) {
        uint256 loanAmount = loans[accountAddress];
        uint256 elapsedTime = block.timestamp - accounts[accountAddress].depositTimestamp;
        uint256 yearsElapsed = elapsedTime * SCALE / SECONDS_PER_YEAR;
        return (loanAmount * LOAN_INTEREST_RATE * yearsElapsed) / (100 * SCALE);
    }
}
