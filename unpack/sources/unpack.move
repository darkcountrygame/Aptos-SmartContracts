module creator_addr::unpacking
{
use creator_addr::minter;

use std::vector;
use std::bcs;
use aptos_std::from_bcs;
use std::hash;
use aptos_framework::timestamp;
use aptos_framework::transaction_context;

use aptos_framework::event;
use aptos_framework::account;
use std::error;
use std::signer;
use aptos_framework::account::Account;
use aptos_framework::aptos_account;
use aptos_framework::object::{Self, ExtendRef, Object};

use aptos_std::table::{Self, Table};
use std::string::{Self, String, utf8};

use aptos_token::token;
use aptos_token::property_map;

struct MyRefs has key, store {
    extend_ref: ExtendRef,
}    

struct UnpackStore has key
{
    unpacked_templates: Table<address, vector<u64>>,
    unpack_event: event::EventHandle<vector<u64>>
}

fun create_obj_signer(caller: &signer)
{
    let caller_address = signer::address_of(caller);
    let constructor_ref = object::create_object(caller_address);
    let object_address = object::address_from_constructor_ref(&constructor_ref);

    // Create an account alongside the object.
    aptos_account::create_account(object_address);

    // Store an ExtendRef alongside the object.
    let object_signer = object::generate_signer(&constructor_ref);
    let extend_ref = object::generate_extend_ref(&constructor_ref);
    
    move_to(
      caller,
      MyRefs { extend_ref: extend_ref },
    );
}

fun init_module(account: &signer)
{
    create_obj_signer(account);

    let store = UnpackStore {
        unpacked_templates: table::new(),
        unpack_event: account::new_event_handle<vector<u64>>(account)
    };

    move_to(account, store);
}

entry fun claim(account: &signer) acquires MyRefs, UnpackStore
{
    let unpack_table = borrow_global_mut<UnpackStore>(@creator_addr);
    let tokens = table::borrow_mut(&mut unpack_table.unpacked_templates, signer::address_of(account));
    let size = vector::length(tokens);

    let my_refs = borrow_global<MyRefs>(@creator_addr);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);

    for (i in 0..size)
    {
        let template_id = *vector::borrow(tokens, i);
        minter::mint_template(&object_signer, signer::address_of(account), template_id);
    };

    *tokens = vector::empty<u64>();
}

public entry fun unpack_any(account: &signer, token_name: String, collection_name: String) acquires UnpackStore
{
    let p = get_p(signer::address_of(account), token_name, collection_name);
    let n = get_n(signer::address_of(account), token_name, collection_name);
    let packtype = get_packtype(signer::address_of(account), token_name, collection_name);

    let tokens = gen_n_ctgr(account, n, p, packtype);

    let unpack_table = borrow_global_mut<UnpackStore>(@creator_addr);
    let unpacker_address = signer::address_of(account);

    if (!table::contains(&unpack_table.unpacked_templates, unpacker_address))
    {
        table::upsert(&mut unpack_table.unpacked_templates, unpacker_address, tokens);
        event::emit_event<vector<u64>>(
            &mut unpack_table.unpack_event, 
            tokens
        );
    }   
    else
    {
        let owner_unpacked_templates = table::borrow_mut(&mut unpack_table.unpacked_templates, unpacker_address);
        vector::append(owner_unpacked_templates, tokens);
    };

    let col_creator: address = @collection_creator_addr;

    if (collection_name == utf8(b"packschangelings"))
    {
        col_creator = @packs_collection_creator_addr;
    };

    token::burn(account, col_creator, collection_name, token_name, 0, 1);
}

public entry fun unpack(account: &signer, token_name: String) acquires UnpackStore
{
    let changelings_collection = utf8(b"changelings");
    let p = get_p(signer::address_of(account), token_name, changelings_collection);
    let n = get_n(signer::address_of(account), token_name, changelings_collection);
    let packtype = get_packtype(signer::address_of(account), token_name, changelings_collection);

    let tokens = gen_n_ctgr(account, n, p, packtype);

    let unpack_table = borrow_global_mut<UnpackStore>(@creator_addr);
    let unpacker_address = signer::address_of(account);

    if (!table::contains(&unpack_table.unpacked_templates, unpacker_address))
    {
        table::upsert(&mut unpack_table.unpacked_templates, unpacker_address, tokens);
        event::emit_event<vector<u64>>(
            &mut unpack_table.unpack_event, 
            tokens
        );
    }   
    else
    {
        let owner_unpacked_templates = table::borrow_mut(&mut unpack_table.unpacked_templates, unpacker_address);
        vector::append(owner_unpacked_templates, tokens);
    };

    token::burn(account, @collection_creator_addr, utf8(b"changelings"), token_name, 0, 1);
}

fun pseudo_random(add:address, number1:u64, max:u64): u64
{
    let x = bcs::to_bytes<address>(&add);
    let y = bcs::to_bytes<u64>(&number1);
    let z = bcs::to_bytes<u64>(&timestamp::now_seconds());

    vector::append(&mut x,y);
    vector::append(&mut x,z);

    let script_hash: vector<u8> = transaction_context::get_script_hash();
    vector::append(&mut x,script_hash);

    let tmp = hash::sha2_256(x);

    let data = vector<u8>[];
    let i = 24;

    while (i < 32)
    {
        let x =vector::borrow(&tmp,i);
        vector::append(&mut data,vector<u8>[*x]);
        i= i+1;
    };

    assert!(max > 0,999);

    let random = from_bcs::to_u64(data) % max + 1;
    random
}

fun string_to_u64(s: &String): u64 
{
    let chars = string::bytes(s);
    let result: u64 = 0u64;
    let base = 1u64;
        
    let n = vector::length(chars);
        
    let i = 0;
    while (i < n) {
        let index = n - 1 - i;
        let byte = *vector::borrow(chars, index);
            
        // Ensure the byte is a valid digit ('0' to '9')
        assert!(byte >= 48 && byte <= 57, 1);
            
        let digit = (byte as u64) - 48;
        result = result + digit * base;
        base = base * 10;
            
        i = i + 1;
    };
        
    result
}

fun get_p(owner: address, token_name: String, collection_name: String): vector<u64>
{
    let col_creator: address = @collection_creator_addr;

    if (collection_name == utf8(b"packschangelings"))
    {
        col_creator = @packs_collection_creator_addr;
    };

    let token_id = token::create_token_id_raw(col_creator, collection_name, token_name, 0);
    let token_properties = token::get_property_map(owner, token_id);

    let p: vector<u64> = vector::empty();

    let common = string_to_u64(&property_map::read_string(&token_properties, &utf8(b"common")));
    let rare = string_to_u64(&property_map::read_string(&token_properties, &utf8(b"rare")));
    let epic = string_to_u64(&property_map::read_string(&token_properties, &utf8(b"epic")));
    let legendary = string_to_u64(&property_map::read_string(&token_properties, &utf8(b"legendary")));
    let mythical = string_to_u64(&property_map::read_string(&token_properties, &utf8(b"mythical")));

    vector::push_back(&mut p, common);
    vector::push_back(&mut p, rare);
    vector::push_back(&mut p, epic);
    vector::push_back(&mut p, legendary);
    vector::push_back(&mut p, mythical);

    p
}

fun get_n(owner: address, token_name: String, collection_name: String): u64
{
    let col_creator: address = @collection_creator_addr;

    if (collection_name == utf8(b"packschangelings"))
    {
        col_creator = @packs_collection_creator_addr;
    };

    let token_id = token::create_token_id_raw(col_creator, collection_name, token_name, 0);
    let token_properties = token::get_property_map(owner, token_id);

    let n = string_to_u64(&property_map::read_string(&token_properties, &utf8(b"quantity")));
    
    n
}

fun get_packtype(owner: address, token_name: String, collection_name: String): String
{
    let col_creator: address = @collection_creator_addr;

    if (collection_name == utf8(b"packschangelings"))
    {
        col_creator = @packs_collection_creator_addr;
    };

    let token_id = token::create_token_id_raw(col_creator, collection_name, token_name, 0);
    let token_properties = token::get_property_map(owner, token_id);

    let packtype = property_map::read_string(&token_properties, &utf8(b"packtype"));

    packtype
}

const COMMON_OFFSET: u64 = 0; 
const RARE_OFFSET: u64 = 15;
const EPIC_OFFSET: u64 = 101;
const LEGENDARY_OFFSET: u64 = 186;
const MYTHICAL_OFFSET: u64 = 269;

const COMMON_HEROES: u64 = 0;
const HEROES: u64 = 80;

const COMMON_CARDS: u64 = 15;
const RARE_CARDS: u64 = 6;
const EPIC_CARDS: u64 = 5;
const LEGENDARY_CARDS: u64 = 3;
const MYTHICAL_CARDS: u64 = 1;

const LANDS: u64 = 1;

fun gen_token(account_address: address, number: u64, rarity: String, type: String) : u64
{
    let heroes: u64 = 0;
    let cards: u64 = 0;
    let offset: u64 = 0;

    if (rarity == utf8(b"common"))
    {
        heroes = COMMON_HEROES;
        cards = COMMON_CARDS;
        offset = COMMON_OFFSET;
    }
    else
    {
        heroes = HEROES;

        if (rarity == utf8(b"rare"))
        {
            cards = RARE_CARDS;
            offset = RARE_OFFSET;
        }
        else if (rarity == utf8(b"epic"))
        {
            cards = EPIC_CARDS;
            offset = EPIC_OFFSET;
        }
        else if (rarity == utf8(b"legendary"))
        {
            cards = LEGENDARY_CARDS;
            offset = LEGENDARY_OFFSET;
        }
        else if (rarity == utf8(b"mythical"))
        {
            cards = MYTHICAL_CARDS;
            offset = MYTHICAL_OFFSET;
        };
    };

    let token = 0;

    if (type == utf8(b"hero"))
    {
        let hero_offset = pseudo_random(account_address, number, heroes);
        token = offset + hero_offset;
    }
    else if (type == utf8(b"card"))
    {
        let card_offset = pseudo_random(account_address, number, cards);
        token = offset + heroes + card_offset;
    };

    token
}

fun gen_n_ctgr(account: &signer, n: u64, p: vector<u64>, packtype: String): vector<u64>
{
    let addr = signer::address_of(account);

    let categories: vector<u64> = vector::empty();
    let tokens: vector<u64> = vector::empty();

    let total_probability = 0;

    for (i in 0..vector::length<u64>(&p))
    {
        total_probability = total_probability + *vector::borrow(&p, i);
    };

    for (i in 0..n)
    {
        let ctgr = gen_category(addr, i, total_probability, p);
        vector::push_back(&mut categories, ctgr);
    };

    for (i in 0..n)
    {
        let ctgr = *vector::borrow(&categories, i);
        let rarity: String = utf8(b"");

        if (ctgr == 0)
        {
            rarity = utf8(b"common");
        }
        else if (ctgr == 1)
        {
            rarity = utf8(b"rare");
        }
        else if (ctgr == 2)
        {
            rarity = utf8(b"epic");
        }
        else if (ctgr == 3)
        {
            rarity = utf8(b"legendary");
        }
        else if (ctgr == 4)
        {
            rarity = utf8(b"mythical");
        };

        let token = gen_token(addr, i, rarity, packtype);
        vector::push_back(&mut tokens, token);
    };

    tokens
}

fun add_n_ctgr(account: &signer, n: u64, p: vector<u64>): vector<u64>
{
    let addr = signer::address_of(account);

    let categories: vector<u64> = vector::empty();
    let tokens: vector<u64> = vector::empty();

    let total_probability = 0;

    for (i in 0..vector::length<u64>(&p))
    {
        total_probability = total_probability + *vector::borrow(&p, i);
    };

    for (i in 0..n)
    {
        let ctgr = gen_category(addr, i, total_probability, p);
        vector::push_back(&mut categories, ctgr);
    };

    for (i in 0..n)
    {
        let ctgr = *vector::borrow(&categories, i);
        let token: u64 = 0;

        if (ctgr == 0)
        {
            //common -> #41 320-339, 360
            let item = pseudo_random(addr, i, 41);

            if (item == 40)
            {
                //land
                token = 360;
            }
            else
            {
                //card
                token = 320 + item;
            }
        }
        else if (ctgr == 1)
        {
            //rare -> #80 0-7, 32-39, 64-71, 96-103, 128-135, 160-167, 192-199, 224-231, 256-263, 288-295, 
            //rare -> #14 347-359, 361

            let item = pseudo_random(addr, i, 94);
            if (item == 93)
            {
                //land
                token = 361
            }
            else if (item >= 80)
            {
                //card 
                token = 347 + (item - 80);   
            }
            else
            {
                //hero
                let r = item % 8;
                let k = item / 8;

                token = 32*k + r;
            }
        }
        else if (ctgr == 2)
        {
            //epic -> #5 340-343, 362

            let item = pseudo_random(addr, i, 85);
            if (item == 84)
            {
                //land
                token = 362;
            }
            else if (item >= 80)
            {
                //card 
                token = 340 + (item - 80);   
            }
            else
            {
                //hero
                let r = item % 8;
                let k = item / 8;

                token = 8 + 32*k + r;
            }
        }
        else if (ctgr == 3)
        {
            //legendary -> #3 344-345, 363

            let item = pseudo_random(addr, i, 83);
            if (item == 82)
            {
                //land
                token = 363;
            }
            else if (item >= 80)
            {
                //card 
                token = 344 + (item - 80);   
            }
            else
            {
                //hero
                let r = item % 8;
                let k = item / 8;

                token = 16 + 32*k + r;
            }
        }
        else if (ctgr == 4)
        {
            //mythical -> #2 346, 364

            let item = pseudo_random(addr, i, 82);
            if (item == 81)
            {
                //land
                token = 364;
            }
            else if (item >= 80)
            {
                //card 
                token = 346 + (item - 80);   
            }
            else
            {
                //hero
                let r = item % 8;
                let k = item / 8;

                token = 24 + 32*k + r;
            }
        };

        vector::push_back(&mut tokens, token);
    };

    tokens
}

public fun gen_category(addr: address, seed: u64, d: u64, p: vector<u64>): u64
{
    let sample = pseudo_random(addr, seed, d);
    let c_p = *vector::borrow(&p, 0);
    let result = 0;

    for (i in 1..vector::length(&p))
    {
        if (sample <= c_p)
        {
            break
        };

        c_p = c_p + *vector::borrow(&p, i);
        result = result + 1;
    };

    result
}

#[view]
public fun get_unpacked_tokens(unpacker_address: address): vector<u64> acquires UnpackStore
{
    let unpack_table = borrow_global<UnpackStore>(@creator_addr);
    *table::borrow(&unpack_table.unpacked_templates, unpacker_address)
}

#[view]
public fun get_unpacker_object_addr(): address acquires MyRefs
{
    let my_refs = borrow_global<MyRefs>(@creator_addr);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);
    signer::address_of(&object_signer)
}

}