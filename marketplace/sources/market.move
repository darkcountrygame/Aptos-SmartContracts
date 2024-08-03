module dev::market
{
use dev::permissions;
use token::sdm;

use std::fixed_point32::{Self, FixedPoint32};
use std::signer;
use std::timestamp;
use std::vector;
use std::string::{String, utf8};
use aptos_std::table::{Self, Table};
use aptos_token::token;
use aptos_framework::event;
use aptos_framework::coin;
use aptos_framework::aptos_coin;

struct Sale has store, drop, copy
{
    id: u64,
    seller: address,
    name: String,
    description: String,
    tokens: vector<String>,
    price: u64,
    token_type: String
}

struct FeeConfig has key, drop, copy
{
    collection_fee: FixedPoint32,
    marketplace_fee: FixedPoint32
}

struct SaleStore has key
{
    list_of_sales: vector<Sale>
}

#[event]
struct CreateSaleEvent has drop, store {
    sale: Sale
}

#[event]
struct BuyEvent has drop, store {
    sale_id: u64,
    buyer: address
}

struct StakingStore has key
{
    staked_tokens: Table<u64, vector<token::Token>>,
}

public entry fun init(account: &signer)
{
    assert!(permissions::is_host(signer::address_of(account)), 1);

    let store = SaleStore {
        list_of_sales: vector::empty<Sale>()
    };

    move_to(account, store);

    let fee_config = FeeConfig{
        collection_fee: fixed_point32::create_from_rational(5, 100),
        marketplace_fee: fixed_point32::create_from_rational(1, 100)
    };

    move_to(account, fee_config);
}

public entry fun set_collection_fee(account: &signer, collection_fee_numerator: u64, collection_fee_denominator: u64) acquires FeeConfig
{
    assert!(permissions::check_permission(signer::address_of(account)), 1);
    
    let fee_config = borrow_global_mut<FeeConfig>(@host);
    fee_config.collection_fee = fixed_point32::create_from_rational(collection_fee_numerator, collection_fee_denominator);
}

public entry fun set_marketplace_fee(account: &signer, marketplace_fee_numerator: u64, marketplace_fee_denominator: u64) acquires FeeConfig
{
    assert!(permissions::check_permission(signer::address_of(account)), 1);

    let fee_config = borrow_global_mut<FeeConfig>(@host);
    fee_config.marketplace_fee = fixed_point32::create_from_rational(marketplace_fee_numerator, marketplace_fee_denominator);
}

public entry fun update_sale_name(account: &signer, sale_id: u64, new_name: String) acquires SaleStore
{
    let account_addr = signer::address_of(account);
    let sale_store = borrow_global_mut<SaleStore>(@host);
    let list_of_sales = &mut sale_store.list_of_sales;

    let sale_index = find_sale(list_of_sales, sale_id);
    let sale = vector::borrow_mut(list_of_sales, sale_index);

    assert!(sale.seller == account_addr, 6);

    sale.name = new_name;
}

public entry fun update_sale_description(account: &signer, sale_id: u64, new_description: String) acquires SaleStore
{
    let account_addr = signer::address_of(account);
    let sale_store = borrow_global_mut<SaleStore>(@host);
    let list_of_sales = &mut sale_store.list_of_sales;

    let sale_index = find_sale(list_of_sales, sale_id);
    let sale = vector::borrow_mut(list_of_sales, sale_index);

    assert!(sale.seller == account_addr, 6);

    sale.description = new_description;
}

public entry fun update_sale_price(account: &signer, sale_id: u64, new_price: u64) acquires SaleStore
{
    let account_addr = signer::address_of(account);
    let sale_store = borrow_global_mut<SaleStore>(account_addr);
    let list_of_sales = &mut sale_store.list_of_sales;

    let sale_index = find_sale(list_of_sales, sale_id);
    let sale = vector::borrow_mut(list_of_sales, sale_index);

    assert!(sale.seller == account_addr, 6);

    sale.price = new_price;
}

public entry fun create_sale(account: &signer, name: String, description: String, tokens: vector<String>, price: u64, token_type: String) acquires SaleStore, StakingStore
{
    //create new sale

    coin::register<sdm::SDM>(account);

    let id = timestamp::now_microseconds();
    let seller = signer::address_of(account);

    let sale = Sale {
        id, 
        seller,
        name,
        description,
        tokens,
        price,
        token_type
    };

    //move sale to SaleStore

    event::emit(CreateSaleEvent{sale});

    let sale_store = borrow_global_mut<SaleStore>(@host);
    vector::push_back(&mut sale_store.list_of_sales, sale);

    //init stakingStore if doesn't exitst

    if (!exists<StakingStore>(seller))
    {
        move_to(account, StakingStore {
            staked_tokens: table::new<u64, vector<token::Token>>()
        });
    };

    //withdraw tokens from account

    let tokens_for_sale = vector::empty<token::Token>();

    for (i in 0..vector::length(&tokens))
    {
        let token_name = *vector::borrow(&tokens, i);
        let token_id = token::create_token_id_raw(@collection_creator, utf8(b"Dark Country"), token_name, 0);

        let withdrawn_token = token::withdraw_token(account, token_id, 1);

        vector::push_back(&mut tokens_for_sale, withdrawn_token);
    };

    //move tokens to StakingStore

    let staking_store = borrow_global_mut<StakingStore>(seller);
    let staked_tokens = &mut staking_store.staked_tokens;

    table::add(staked_tokens, id, tokens_for_sale);
}

fun find_sale(list_of_sales: &vector<Sale>, sale_id: u64): u64
{
    let sale_index = 0;
    let found: bool = false;

    for (i in 0..vector::length(list_of_sales))
    {
        let sale: Sale = *vector::borrow(list_of_sales, i);
        if (sale.id == sale_id)
        {
            sale_index = i;
            found = true;
            break
        };
    };

    assert!(found, 6);

    sale_index
}

fun transfer_coin(from: &signer, to: address, amount: u64, token_type: String)
{
    if (token_type == utf8(b"APT"))
    {
        coin::transfer<aptos_coin::AptosCoin>(from, to, amount);
    }
    else if (token_type == utf8(b"SDM"))
    {
        coin::transfer<sdm::SDM>(from, to, amount);
    }
}

public entry fun buy(buyer: &signer, sale_id: u64) acquires SaleStore, FeeConfig, StakingStore
{
    //find sale

    let sale_store = borrow_global_mut<SaleStore>(@host);
    let list_of_sales = &mut sale_store.list_of_sales;

    let sale_index = find_sale(list_of_sales, sale_id);
    let sale = vector::remove(list_of_sales, sale_index);

    //calculate fees

    let fee_config = borrow_global<FeeConfig>(@host);
    let collection_fee = fixed_point32::multiply_u64(sale.price, fee_config.collection_fee);
    let marketplace_fee = fixed_point32::multiply_u64(sale.price, fee_config.marketplace_fee);
    let net_amount = sale.price - collection_fee - marketplace_fee;

    //send APT to seller

    let token_type = sale.token_type;

    transfer_coin(buyer, @host, collection_fee, token_type);
    transfer_coin(buyer, @host, marketplace_fee, token_type);
    transfer_coin(buyer, sale.seller, net_amount, token_type);

    //send tokens to buyer

    let staking_store = borrow_global_mut<StakingStore>(sale.seller);
    let staked_tokens = &mut staking_store.staked_tokens;

    let tokens = table::remove(staked_tokens, sale_id);

    for (i in 0..vector::length(&tokens))
    {
        let withdrawn_token = vector::pop_back(&mut tokens);
        token::deposit_token(buyer, withdrawn_token);
    };

    vector::destroy_empty(tokens); 
}

public entry fun delete_sale(account: &signer, sale_id: u64) acquires SaleStore, StakingStore
{
    //find sale

    let sale_store = borrow_global_mut<SaleStore>(@host);
    let list_of_sales = &mut sale_store.list_of_sales;

    let sale_index = find_sale(list_of_sales, sale_id);
    let sale = vector::remove(list_of_sales, sale_index);

    assert!(signer::address_of(account) == sale.seller, 1);

    //send tokens back to seller

    let staking_store = borrow_global_mut<StakingStore>(sale.seller);
    let staked_tokens = &mut staking_store.staked_tokens;

    let tokens = table::remove(staked_tokens, sale_id);

    for (i in 0..vector::length(&tokens))
    {
        let withdrawn_token = vector::pop_back(&mut tokens);
        token::deposit_token(account, withdrawn_token);
    };

    vector::destroy_empty(tokens); 
}

#[view]
public fun get_sales(): vector<Sale> acquires SaleStore
{
    let sale_store = borrow_global<SaleStore>(@host);
    sale_store.list_of_sales
}

}