module creator_addr::minter 
{
use creator_addr::templates;

use std::error;
use std::signer;
use aptos_framework::account::Account;
use aptos_framework::aptos_account;
use aptos_framework::object::{Self, ExtendRef, Object};

use std::string::{Self, utf8, String};
use aptos_token::token;

use std::vector;
use 0x1::bcs;
use 0x1::string_utils;

struct MyRefs has key, store {
    extend_ref: ExtendRef,
}

struct CollectionData has key
{
    collection_name: String,
    minted_tokens_count: u64,
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

fun init_module(account: &signer) acquires MyRefs
{
    create_obj_signer(account);
    let my_refs = borrow_global<MyRefs>(@creator_addr);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);
    
    //create collection

    let collection_name = string::utf8(b"changelings");
    let collection_description = string::utf8(b"");
    let collection_uri = string::utf8(b"");
    let mutate_setting = vector<bool>[true, true, true];

    token::create_collection(
        &object_signer,
        collection_name,
        collection_description,
        collection_uri,
        0, //unlimited
        mutate_setting
    );

    move_to(account, CollectionData {
        collection_name: collection_name,
        minted_tokens_count: 0
    });
}

//mint_template

public entry fun mint_template(caller: &signer, to:address, template_id: u64) acquires CollectionData, MyRefs
{
    let is_unpacker: bool = signer::address_of(caller) == @unpacker_addr;
    let is_creator: bool = signer::address_of(caller) == @creator_addr;
    let is_market: bool = signer::address_of(caller) == @market_addr;
    assert!(is_unpacker || is_creator || is_market, 1);

    mint_template_internal(to, template_id);
}

fun mint_template_internal(to: address, template_id: u64) acquires CollectionData, MyRefs
{
    let template = templates::get_template(template_id);
    let module_data_mut = borrow_global_mut<CollectionData>(@creator_addr);
    let my_refs = borrow_global<MyRefs>(@creator_addr);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);

    let token_mutability_settings = vector<bool>[true, true, true, true, true];
    
    module_data_mut.minted_tokens_count = module_data_mut.minted_tokens_count + 1;

    let token_name = string::utf8(b"#");
    string::append(&mut token_name, 
    string_utils::to_string_with_integer_types<u64>(&module_data_mut.minted_tokens_count));

    let description = templates::get_description(&template);
    let uri = templates::get_uri(&template);
    let property_names = templates::get_property_names(&template);
    let property_types = templates::get_property_types(&template);
    let property_values = templates::get_property_values(&template);

    vector::push_back(&mut property_names, utf8(b"Template"));
    vector::push_back(&mut property_types, utf8(b"u64"));
    vector::push_back(&mut property_values, bcs::to_bytes<u64>(&template_id));

    let my_BURNABLE_BY_OWNER: vector<u8> = b"TOKEN_BURNABLE_BY_OWNER";
    let to_burn_tokens = true;

    vector::push_back(&mut property_names, utf8(my_BURNABLE_BY_OWNER));
    vector::push_back(&mut property_types, utf8(b"bool"));
    vector::push_back(&mut property_values, bcs::to_bytes<bool>(&to_burn_tokens));

    let token_data_id = token::create_tokendata(
        &object_signer,
        module_data_mut.collection_name,
        token_name,
        description,
        0, //maximum amount
        uri,
        @creator_addr, //payee address
        3, //denominator
        1, //numinator
        token::create_token_mutability_config(&token_mutability_settings),
        property_names,
        property_values,
        property_types
    );

    token::mint_token_to(
        &object_signer,
        to,
        token_data_id,
        1 //amount to mint
    );
}

#[view]
public fun get_collection_creator_object(): address acquires MyRefs
{
    let my_refs = borrow_global<MyRefs>(@creator_addr);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);
    signer::address_of(&object_signer)
}

}
