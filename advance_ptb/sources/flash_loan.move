module 0x0::flash_loan;

use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};
use sui::sui::SUI;

/// The bank holds pooled liquidity
public struct Bank has key {
    id: UID,
    reserves: Balance<SUI>,
    fee_basis_points: u64, // e.g., 50 = 0.5%
}

/// THE HOT POTATO — no abilities!
/// Must be destroyed by calling repay() in the same PTB
public struct LoanReceipt {
    amount: u64,
    fee: u64,
    // Optional: include a unique nonce or bank ID for safety
}

// --- Setup ---

public fun create_bank(ctx: &mut TxContext): Bank {
    Bank {
        id: object::new(ctx),
        reserves: balance::zero(),
        fee_basis_points: 50,
    }
}

public fun deposit(bank: &mut Bank, coin: Coin<SUI>) {
    let balance = coin::into_balance(coin);
    balance::join(&mut bank.reserves, balance);
}

// --- The Flash Loan ---

/// Withdraws `amount` from the bank and returns it + a hot potato receipt
public fun borrow(
    bank: &mut Bank,
    amount: u64,
    ctx: &mut TxContext
): (Coin<SUI>, LoanReceipt) {
    assert!(amount <= balance::value(&bank.reserves), 0);

    let loan_coin = coin::take(&mut bank.reserves, amount, ctx);

    let fee = (amount * bank.fee_basis_points) / 10000;

    let receipt = LoanReceipt {
        amount,
        fee,
    };

    (loan_coin, receipt)
}

/// Consumes the receipt and repays principal + fee
/// THE ONLY WAY TO DESTROY THE HOT POTATO
public fun repay(
    bank: &mut Bank,
    receipt: LoanReceipt, // <-- must be consumed!
    payment: Coin<SUI>
) {
    let LoanReceipt { amount, fee } = receipt; // destructuring destroys it

    let total_due = amount + fee;
    assert!(coin::value(&payment) >= total_due, 0);

    // Return principal to reserves
    let mut payment_balance = coin::into_balance(payment);

    // Split off fee if overpaid (optional, or just assert exact)
    let fee_balance = balance::split(&mut payment_balance, fee);
    balance::join(&mut bank.reserves, fee_balance);
    // In a real contract, fee_balance would go to protocol treasury

    // Return principal
    let principal_balance = balance::split(&mut payment_balance, amount);
    balance::join(&mut bank.reserves, principal_balance);

    // Destroy leftover (or return to caller)
    balance::destroy_zero(payment_balance);
}
