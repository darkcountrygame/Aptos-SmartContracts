module dev::minter 
{
use dev::templates;
use dev::permissions;

use std::signer;

use aptos_framework::aptos_account;
use aptos_framework::object::{Self, ExtendRef};

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

struct MyRefs2 has key, store {
    extend_ref: ExtendRef,
}

struct CollectionData2 has key
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
    let extend_ref = object::generate_extend_ref(&constructor_ref);
    
    move_to(
      caller,
      MyRefs2 { extend_ref: extend_ref },
    );
}

public entry fun init(account: &signer) acquires MyRefs2
{
    assert!(permissions::is_host(signer::address_of(account)), 1);
    create_obj_signer(account);
    let my_refs = borrow_global<MyRefs2>(@host);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);
    
    //create collection

    let collection_name = string::utf8(b"Dark Country");
    let collection_description = string::utf8(b"This is Dark Country Changelings collection. There are packs, cards, heroes and lands in this collection. Each pack contains game items, depends on pack type those can be cards, heroes or lands.");
    let collection_uri = string::utf8(b"https://cdn.darkcountry.io/gold_logo.png");
    let mutate_setting = vector<bool>[true, true, true];

    token::create_collection(
        &object_signer,
        collection_name,
        collection_description,
        collection_uri,
        0, //unlimited
        mutate_setting
    );

    move_to(account, CollectionData2 {
        collection_name: collection_name,
        minted_tokens_count: 0
    });
}

public entry fun restart(account: &signer) acquires CollectionData2
{
    assert!(permissions::is_host(signer::address_of(account)), 1);
    let collection_data = borrow_global_mut<CollectionData2>(@host);
    collection_data.minted_tokens_count = 0;
}

//mint_template

public entry fun mint_template(caller: &signer, to:address, template_id: u64) acquires CollectionData2, MyRefs2
{
    assert!(permissions::check_mint_permissions(signer::address_of(caller)), 1);
    
    mint_template_internal(to, template_id);
}

fun mint_template_internal(to: address, template_id: u64) acquires CollectionData2, MyRefs2
{
    let template = templates::get_template(template_id);
    let module_data_mut = borrow_global_mut<CollectionData2>(@host);
    let my_refs = borrow_global<MyRefs2>(@host);
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
        @host, //payee address
        100, //denominator
        5, //numinator
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
public fun get_collection_creator_object(): address acquires MyRefs2
{
    let my_refs = borrow_global<MyRefs2>(@host);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);
    signer::address_of(&object_signer)
}

}
