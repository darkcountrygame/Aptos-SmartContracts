module creator_addr::templates
{

use std::signer;
use std::string::{Self, String, utf8};
use std::vector;

use aptos_framework::event;
use aptos_framework::account;

use 0x1::bcs;
use aptos_std::table::{Self, Table};

struct Template has store, drop, copy
{
    id: u64,
    name: String,
    description: String,
    uri: String,
    property_names: vector<String>,
    property_types: vector<String>,
    property_values_bytes: vector<vector<u8>>
}

struct TemplateStore has key
{
    templates: Table<u64, Template>,
    add_template_event: event::EventHandle<Template>
}

fun init_module(account: &signer)
{
    let templates_table = TemplateStore {
        templates: table::new(),
        add_template_event: account::new_event_handle<Template>(account)
    };

    move_to(account, templates_table);
}

public entry fun add_template(creator: &signer, template_id: u64, name: String, description: String, uri: String,
                              property_names: vector<String>, property_values: vector<String>) acquires TemplateStore
{
    assert!(signer::address_of(creator) == @creator_addr, 1);

    let creator_address = signer::address_of(creator);
    let templates_table = borrow_global_mut<TemplateStore>(creator_address);

    let property_values_bytes: vector<vector<u8>> = vector::empty();
    let property_types: vector<String> = vector::empty();

    for (i in 0..vector::length(&property_values))
    {
        //EXPLANATION: property_values_bytes[i] = bcs::to_bytes(propery_values[i])
        vector::push_back(&mut property_values_bytes,
        bcs::to_bytes(vector::borrow(&property_values, i)));

        vector::push_back(&mut property_types, utf8(b"0x1::string::String"));
    };

    let new_template = Template {
        id: template_id,
        name,
        description,
        uri,
        property_names,
        property_types,
        property_values_bytes
    };

    table::upsert(&mut templates_table.templates, template_id, new_template);

    event::emit_event<Template>(
        &mut borrow_global_mut<TemplateStore>(creator_address).add_template_event,
        new_template
    );    
}

#[view] 
public fun get_template(template_id: u64): Template acquires TemplateStore
{
    let templates_table = borrow_global<TemplateStore>(@creator_addr);
    *table::borrow(&templates_table.templates, template_id)
}

public fun get_description(temp: &Template) : String
{
    temp.description
}

public fun get_uri(temp: &Template) : String
{
    temp.uri
}

public fun get_property_names(temp: &Template) : vector<String>
{
    temp.property_names
}


public fun get_property_types(temp: &Template) : vector<String>
{
    temp.property_types
}

public fun get_property_values(temp: &Template) : vector<vector<u8>>
{
    temp.property_values_bytes
}

}