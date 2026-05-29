module 0x0::lottery;


use sui::random::{Random, RandomGenerator, new_generator};
use sui::deny_list_tests::X;

public struct Lottery has key {
    id: UID,
    winner: Option<address>,
    participants: vector<address>
}

entry fun create_lottery(ctx: &mut TxContext) {
    let  x = Lottery {
    id: object::new(ctx),
    winner: option::none(),
    participants: vector<address>[]
};

transfer::share_object(x)

}



// Entry functions CAN use randomness — they are called directly by users.
// Public functions CANNOT — the compiler rejects them to prevent test-and-abort.
entry fun draw_winner( lottery: &mut Lottery, rnd: &Random,  ctx: &mut TxContext )
{
    // 1. Create a generator from the shared randomness
    let mut gen = new_generator(rnd, ctx);
    // 2. Generate a random index within the participant range
    let winner_idx = gen.generate_u64_in_range(0, lottery.participants.length());
    // 3. Assign the winner
    std::debug::print(&winner_idx);
    lottery.winner = option::some(lottery.participants[winner_idx]);
}


entry fun add_participant(lottery: &mut Lottery, participant: address){
    lottery.participants.push_back(participant);
}


// In tests, you can create a deterministic Random object
#[test]
fun test_draw_winner() {
    use sui::test_scenario;
    use sui::random::{Self, Random};

    let mut scenario = test_scenario::begin(@0x0);

    // Both use scenario.ctx() — objects land in the scenario inventory
    let mut ctx = tx_context::dummy();
    random::create_for_testing(&mut ctx);
    create_lottery(&mut ctx);
    scenario.next_tx(@0x0);  // advance so shared objects are visible

    let mut random_state = scenario.take_shared<Random>();
    random_state.update_randomness_state_for_testing(
        0,
        x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
        &ctx,
    );

    let mut lottery = scenario.take_shared<Lottery>();
    add_participant(&mut lottery, @0xA);
    add_participant(&mut lottery, @0xB);
    add_participant(&mut lottery, @0xC);

    draw_winner(&mut lottery, &random_state, &mut ctx);

    assert!(option::is_some(&lottery.winner), 0);

    test_scenario::return_shared(lottery);
    test_scenario::return_shared(random_state);
    scenario.end();
}