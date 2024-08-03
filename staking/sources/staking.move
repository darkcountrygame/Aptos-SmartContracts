module dev::staking
{
use dev::permissions;
use aptos_token::token;

use std::signer;

use aptos_framework::aptos_account;
use aptos_framework::object::{Self, ExtendRef};

use std::string::{String, utf8};
use std::vector;

use aptos_framework::event;
use aptos_framework::account;

use aptos_std::table::{Self, Table};
use aptos_token::property_map;

struct StakingStore has key
{
    staked_tokens: Table<address, vector<String>>,
    stake_tokens_event: event::EventHandle<vector<String>>
}

struct StakedToken has drop, store
{
    name: String,
    template_id: u64
}

struct MyRefs has key, store {
    extend_ref: ExtendRef,
}

fun create_obj_signer(caller: &signer)
{
    let caller_address = signer::address_of(caller);
    let constructor_ref = object::create_object(caller_address);
    let object_address = object::address_from_constructor_ref(&constructor_ref);

    // Create an account alongside the object.
    aptos_account::create_account(object_address);

    // Store an ExtendRef alongside the object.
    let extend_ref = object::generate_extend_ref(&constructor_ref);
    
    move_to(
      caller,
      MyRefs { extend_ref: extend_ref },
    );
}

public entry fun init(account: &signer) acquires MyRefs
{
    assert!(permissions::is_host(signer::address_of(account)), 1);

    create_obj_signer(account);
    let my_refs = borrow_global<MyRefs>(@host);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);

    token::opt_in_direct_transfer(&object_signer, true);
    token::opt_in_direct_transfer(account, true);

    let store = StakingStore {
        staked_tokens: table::new(),
        stake_tokens_event: account::new_event_handle<vector<String>>(account)
    };

    move_to(account, store);
}

public entry fun stake_tokens(owner: &signer, nfts: vector<String>) acquires StakingStore, MyRefs
{
    let staked_table = borrow_global_mut<StakingStore>(@host);
    let staker_address = signer::address_of(owner);
    
    let my_refs = borrow_global<MyRefs>(@host);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);

    for (i in 0..vector::length(&nfts))
    {
        let token_name = *vector::borrow(&nfts, i);

        token::transfer_with_opt_in(
            owner,
            @collection_creator,
            utf8(b"Dark Country"),
            token_name,
            0,
            signer::address_of(&object_signer),
            1
        );
    };

    if (!table::contains(&staked_table.staked_tokens, staker_address))
    {
        table::upsert(&mut staked_table.staked_tokens, staker_address, nfts);
        event::emit_event<vector<String>>(
            &mut staked_table.stake_tokens_event, 
            nfts
        );
    }   
    else
    {
        let owner_staked_tokens = table::borrow_mut(&mut staked_table.staked_tokens, staker_address);
        vector::append(owner_staked_tokens, nfts);
    }
}

public entry fun unstake_tokens(owner: &signer, nfts: vector<String>) acquires StakingStore, MyRefs
{
    let staked_table = borrow_global_mut<StakingStore>(@host);
    let owner_addr = signer::address_of(owner);
    let owner_staked_tokens = table::borrow_mut(&mut staked_table.staked_tokens, owner_addr);

    let my_refs = borrow_global<MyRefs>(@host);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);

    for (i in 0..vector::length(&nfts))
    {
        let token_name = *vector::borrow(&nfts, i);

        token::transfer_with_opt_in(
            &object_signer,
            @collection_creator,
            utf8(b"Dark Country"),
            token_name,
            0,
            owner_addr,
            1
        );

        vector::remove_value(owner_staked_tokens, &token_name);
    };
}

fun get_token_template(token_name: String, owner: address): u64
{
    let token_id = token::create_token_id_raw(@collection_creator, utf8(b"Dark Country"), token_name, 0);
    let token_properties = token::get_property_map(owner, token_id);
    let template_id = property_map::read_u64(&token_properties, &utf8(b"Template"));

    template_id
}

#[view]
public fun get_staked_tokens(staker_address: address): vector<StakedToken> acquires StakingStore, MyRefs
{
    let staked_table = borrow_global<StakingStore>(@host);
    let staked_tokens = *table::borrow(&staked_table.staked_tokens, staker_address);

    let result: vector<StakedToken> = vector::empty();

    let my_refs = borrow_global<MyRefs>(@host);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);

    for (i in 0..vector::length(&staked_tokens))
    {
        let token_name = *vector::borrow(&staked_tokens, i);
        vector::push_back(&mut result, StakedToken{name: token_name, template_id: get_token_template(token_name, signer::address_of(&object_signer))});
    };

    result
}

#[view]
public fun get_staker_object_addr(): address acquires MyRefs
{
    let my_refs = borrow_global<MyRefs>(@host);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);
    signer::address_of(&object_signer)
}

}
