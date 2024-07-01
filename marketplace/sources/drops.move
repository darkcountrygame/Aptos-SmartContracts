module creator_addr::drops 
{

use creator_addr::minter;

use std::timestamp;
use std::vector;

use std::string::{Self, String, utf8};

use aptos_framework::coin;  
use aptos_framework::aptos_coin;

use aptos_framework::event;
use aptos_framework::account;
use std::error;
use std::signer;
use aptos_framework::account::Account;
use aptos_framework::aptos_account;
use aptos_framework::object::{Self, ExtendRef, Object};

struct MyRefs has key, store {
    extend_ref: ExtendRef,
}  

struct Sale has copy, drop, store
{
    id: u64,
    start_time: u64,
    end_time: u64,
    count: u64,
    template_id: u64,
    price: u64,
    name: String,
    description: String,
}

struct SaleStore has key, drop
{
    list_of_sales: vector<Sale>
}

entry fun create_obj_signer(caller: &signer)
{
    assert!(signer::address_of(caller) == @creator_addr, 1);

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

entry fun init_sales_store(account: &signer)
{
    assert!(signer::address_of(account) == @creator_addr, 1);

    let sales_store = SaleStore {
        list_of_sales: vector::empty()
    };

    move_to(account, sales_store);
}

entry fun update_sale_name(account: &signer, id: u64, new_name: String) acquires SaleStore
{
    assert!(signer::address_of(account) == @creator_addr, 1);

    let sales_store = borrow_global_mut<SaleStore>(signer::address_of(account));
    let sale_index = find_sale(&sales_store.list_of_sales, id);

    assert!(sale_index != 100000, 2);

    let sale = vector::borrow_mut<Sale>(&mut sales_store.list_of_sales, sale_index);

    sale.name = new_name;
}

entry fun update_sale_description(account: &signer, id: u64, new_description: String) acquires SaleStore
{
    assert!(signer::address_of(account) == @creator_addr, 1);

    let sales_store = borrow_global_mut<SaleStore>(signer::address_of(account));
    let sale_index = find_sale(&sales_store.list_of_sales, id);

    assert!(sale_index != 100000, 2);

    let sale = vector::borrow_mut<Sale>(&mut sales_store.list_of_sales, sale_index);

    sale.description = new_description;
}

entry fun update_sale_time(account: &signer, id: u64, new_start_time: u64, new_end_time: u64) acquires SaleStore
{
    assert!(signer::address_of(account) == @creator_addr, 1);

    let sales_store = borrow_global_mut<SaleStore>(signer::address_of(account));
    let sale_index = find_sale(&sales_store.list_of_sales, id);

    assert!(sale_index != 100000, 2);

    let sale = vector::borrow_mut<Sale>(&mut sales_store.list_of_sales, sale_index);

    sale.start_time = new_start_time;
    sale.end_time = new_end_time;
}

entry fun update_sale_count(account: &signer, id: u64, new_count: u64) acquires SaleStore
{
    assert!(signer::address_of(account) == @creator_addr, 1);

    let sales_store = borrow_global_mut<SaleStore>(signer::address_of(account));
    let sale_index = find_sale(&sales_store.list_of_sales, id);

    assert!(sale_index != 100000, 2);

    let sale = vector::borrow_mut<Sale>(&mut sales_store.list_of_sales, sale_index);

    sale.count = new_count;
}

entry fun update_sale_price(account: &signer, id: u64, new_price: u64) acquires SaleStore
{
    assert!(signer::address_of(account) == @creator_addr, 1);

    let sales_store = borrow_global_mut<SaleStore>(signer::address_of(account));
    let sale_index = find_sale(&sales_store.list_of_sales, id);

    assert!(sale_index != 100000, 2);

    let sale = vector::borrow_mut<Sale>(&mut sales_store.list_of_sales, sale_index);

    sale.price = new_price;
}

entry fun update_sale_template(account: &signer, id: u64, new_template_id: u64) acquires SaleStore
{
    assert!(signer::address_of(account) == @creator_addr, 1);

    let sales_store = borrow_global_mut<SaleStore>(signer::address_of(account));
    let sale_index = find_sale(&sales_store.list_of_sales, id);

    assert!(sale_index != 100000, 2);

    let sale = vector::borrow_mut<Sale>(&mut sales_store.list_of_sales, sale_index);

    sale.template_id = new_template_id;
}

entry fun create_sale(account: &signer, name: String, description: String, start_time: u64, end_time: u64, count: u64, template_id: u64, price: u64) acquires SaleStore
{
    assert!(signer::address_of(account) == @creator_addr, 1);

    let id = timestamp::now_microseconds();
    let sale = Sale {
        id,
        start_time,
        end_time,
        count,
        template_id,
        price,
        name,
        description
    };

    let sales_store = borrow_global_mut<SaleStore>(signer::address_of(account));
    vector::push_back(&mut sales_store.list_of_sales, sale);
}  

fun find_sale(list_of_sales: &vector<Sale>, id: u64) : u64
{
    let index = 100000;
   
    for (i in 0..vector::length(list_of_sales))
    {
        let sale = vector::borrow(list_of_sales, i);

        if (sale.id == id)
        {
            index = i;
            break
        }
    };

    index
}

entry fun delete_sale(account: &signer, id: u64) acquires SaleStore
{
    assert!(signer::address_of(account) == @creator_addr, 1);
    delete_sale_internal(id);
}

fun delete_sale_internal(id: u64) acquires SaleStore
{
    let sales_store = borrow_global_mut<SaleStore>(@creator_addr);
    let sale_index = find_sale(&sales_store.list_of_sales, id);

    assert!(sale_index != 100000, 2);

    vector::remove(&mut sales_store.list_of_sales, sale_index);
}

entry fun buy(buyer: &signer, id: u64) acquires SaleStore, MyRefs
{
    let sales_store = borrow_global_mut<SaleStore>(@creator_addr);
    let sale_index = find_sale(&sales_store.list_of_sales, id);
    
    assert!(sale_index != 100000, 2);
    
    let sale = vector::borrow_mut(&mut sales_store.list_of_sales, sale_index);
	
    assert!(sale.count >= 1, 2);

    let current_time = timestamp::now_microseconds();

    if (sale.start_time == 0 && sale.end_time == 0)
    {
        //ok
    }
    else if (sale.start_time == 0 && sale.end_time != 0)
    {
        assert!(current_time <= sale.end_time, 2)
    }
    else if (sale.start_time != 0 && sale.end_time == 0)
    {
        assert!(sale.start_time <= current_time, 2);
    }
    else
    {
        assert!((sale.start_time <= current_time) && (current_time <= sale.end_time), 2)
    };

    //check if buyer can buy

    sale.count = sale.count - 1;

    coin::transfer<aptos_coin::AptosCoin>(buyer, @creator_addr, sale.price);

    let my_refs = borrow_global<MyRefs>(@creator_addr);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);

    minter::mint_template(&object_signer, signer::address_of(buyer), sale.template_id);

    if (sale.count == 0)
    {
        //delete_sale_internal(id);
    }
}

entry fun buy_multiple(buyer: &signer,  id: u64, count: u64) acquires SaleStore, MyRefs
{
    let sales_store = borrow_global_mut<SaleStore>(@creator_addr);
    let sale_index = find_sale(&sales_store.list_of_sales, id);
    
    assert!(sale_index != 100000, 2);
    
    let sale = vector::borrow_mut(&mut sales_store.list_of_sales, sale_index);

    assert!(sale.count >= count, 2);

    let current_time = timestamp::now_microseconds();

    if (sale.start_time == 0 && sale.end_time == 0)
    {
        //ok
    }
    else if (sale.start_time == 0 && sale.end_time != 0)
    {
        assert!(current_time <= sale.end_time, 2)
    }
    else if (sale.start_time != 0 && sale.end_time == 0)
    {
        assert!(sale.start_time <= current_time, 2);
    }
    else
    {
        assert!((sale.start_time <= current_time) && (current_time <= sale.end_time), 2)
    };

    //check if buyer can buy

    sale.count = sale.count - count;

    coin::transfer<aptos_coin::AptosCoin>(buyer, @creator_addr, count * sale.price);

    let my_refs = borrow_global<MyRefs>(@creator_addr);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);

    for (i in 0..count)
    {
        minter::mint_template(&object_signer, signer::address_of(buyer), sale.template_id);
    };

    if (sale.count == 0)
    {
        //delete_sale_internal(id);
    }
}

#[view]
public fun get_sales(): vector<Sale> acquires SaleStore
{
    let sales_store = borrow_global<SaleStore>(@creator_addr);
    sales_store.list_of_sales
}

#[view]
public fun get_signer_obj_addr(): address acquires MyRefs
{
    let my_refs = borrow_global<MyRefs>(@creator_addr);
    let object_signer = object::generate_signer_for_extending(&my_refs.extend_ref);
    signer::address_of(&object_signer)
}

}
