Intro: This readme is covering several parts of functionality within a framework built within Aptos Dark Country grant program. Also there are scripts on how it is set up for the Dark Country project.

Purpose: A purpose of this project was to create appropriate smart contracts for Dark Country game launch on Aptos blockchain. However, this approach can be re-used as a framework by any web3 project or game.

So called framework has following modules and parts: 

-   Templates approach for tokens(NFTs). What it gives us is an errorless approach on creating new types of items. In practice it is important for gaming NFTs, where you have game items with stats and parameters that are reused, so you don't need to enter them all the time when creating them.

-   Unpacking of NFTs that are packs of items. Suppose we have NFT as a pack of 5 cards, where all cards are set up as templates, and those also have defined chances per every template setup. In our example we will have say 60% to receive one of Common card templates, or Rare cards with 30% chance, and so on.

-   Drops or Initial sale. This is designed to perform the sale of NFT items or packs by appropriate rules. Drop is set up with a number of parameters, such as name, description, start time, end time, amount to sell and price. This will ensure drops can program ways projects can sell items to users. In our examples we will set up a sale of NFT packs that users can unpack in our interface too.

-   Staking of Items. Staking was a core mechanic in our game on other blockchains, there are benefits of doing, such as scarcity of items that will leave marketplaces, providing rewards to those who stake items. Such as lands, cards and heroes.

This general description of what you can find below, and good base code to adapt per your needs. However even now it is very generalized and can be used as is by many projects.

Part 1:  Smart Contracts. This part includes description of all smart contracts(modules) built within the described purpose. This part also includes test coverage and setup scripts for Dark Country assets. Part 1 is described below.

Part 2: Demo website. A website that practically does all we can with those smart contracts, along with provided demo assets, demo NFT pack drops, staking and unpacking of NFT packs. Part 2 can be found in this repository. Demo website for testnet can be found here <https://aptos-dark.vercel.app/>

Let's dive in:
Part 1. Smart Contracts.

Part 1. Smart Contracts. 
-------------------------

Note. A testnet contract is deployed at **0x1ac6713de2cf42540ec69783ed0efe12e363fc0161653b9059008950d6bd0303** address, if you like to have a look and play with it as end user, however we offer demo website that also showcases all of the functionality.

**A. templates** - module that stores and provides access to all templates. The main structure used by this module is Template

```
struct  Template  has  store, drop, copy
{
  id: u64,
  name: String,
  description: String,
  uri: String,
  property_names: vector<String>,
  property_types: vector<String>,
  property_values_bytes: vector<vector<u8>>
}
```

For example, if we want to create a Rectangle token with fields height=6 and width=8, then the corresponding arrays will be as follows (the format and method toBytes() below are conditional). All fields in templates created with templates::add_templates are of type String.

```
property_names = ["height", "width"]
property_types = ["u64", "u64"]
property_values_bytes = [toBytes(6), toBytes(8)]
```

- adds new template, can be called only by contract owner.
```
[main method] templates::add_template(creator: &signer, template_id:
u64, name: String, description: String, uri: String, property_names:
vector <String>, property_values: vector <String>)
```

- returns the fields of
the template according to the given id (Template structure)

```
[view method] templates::get_template(id: u64)
```

Example of returned values templates::get_template(id=100)
```
{
  "description": "",
  "id": "100",
  "name": "Grasp of Doom",
  "property_names": [
    "Name",
    "Rarity",
    "Type"
  ],
  "property_types": [
    "0x1::string::String",
    "0x1::string::String",
    "0x1::string::String"
  ],
  "property_values_bytes": [
    "0x0d4772617370206f6620446f6f6d",
    "0x0472617265",
    "0x0443617264"
  ],
  "uri": "https://cdn.darkcountry.io/ChangelingsCards/NoSlot/graspofdoom.png"
}
```

**B. Minter** - module responsible for token minting, other modules refer to
it

 - minting the token according to the template_id to
the address to. Can only be called by the contract owner and other
modules.
```
[main method] minter::mint_template(account: &signer, to: address,
template_id: u64)
```

- returns the
address of the account to which the collection is registered.
```
[view method] minter::get_collection_creator_object() 
```

**C. Staking** - module for staking and unstaking of tokens(NFTs). Staking
means transferring tokens to contract account.

- stacks all tokens provided in the tokens array
(account must own them in order to stake).
```
[main method] staking::stake_tokens(account: &signer, tokens:
vector<String>) 
```

- returns account those of the std tokens provided in
the tokens array.
```
[main method] staking::unstake_tokens(account: &signer, tokens:
vector<String>)
```

- returns an array of account user tokens currently staked on the contract. Each
element of the array is a token name and its pattern.
```
[view method] staking::get_staked_tokens(account: address)
```

Example of a returned value staking::get_staked_tokens(account=\...)

```
[
  {
    "name": "#9",
    "template_id": "142"
  },
  {
    "name": "#11",
    "template_id": "26"
  }
]
```

- returns the address where the staked tokens are stored
```
[view method] staking::get_staker_object_addr()
```

**D. Unpacking** - the module responsible for unpacking any type of tokens
that has items inside.

Every NFT/token in our case has a type, so those are card, hero, land
and pack.

So packs in our case has such properties:

- **quantity** - number of generated tokens. In our case, 5 tokens are
generated during unpacking.

- **packtype** - pack type (heroes/cards). In this case, only cards will be
generated.

- **common/rare/epic/legendary/mythical** - are fields showing a chance to
generate those packs.

Since the aptos standard library does not support serialization of the
float type, the generation chances should be read as follows.

common_chance = common / (common + rare + ...) = 619 / 1000 = 61.9%
rare_chance = rare / (common + ...) = 310 / 1000 = 31%

- burns pack_token (account must own it) and generates templates
according to pack parameters. To receive tokens, the user must call a
claim. Claim is used to prevent users re-try getting better results of
unpacking.
```
[main method] unpacking::unpack(account: &signer, pack_token:
String)
```

- each of the
templates that were generated by the unpack() method is mangled and sent
to account
```
[main method] unpacking::claim(account: &signer)
```

 - returns the templates generated by the unpack() method;
```
[view method] unpacking::get_unpacked_tokens(account: address)
```

Example of values returned: unpacking::get_unpacked_tokens(account=\...)

```
[
  "101",
  "96",
  "100",
  "96",
  "96"
]
```

-returns the address on behalf of which claim mints tokens
```
[view method] unpacking::get_unpacker_object_addr() 
```

**E. Drops** - selling tokens/NFTs. In our case we are showcasing how to
setup initial sale of NFT packs.

Main structure in this module is - Sale.

```
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
```

- creates a new sale with the specified
parameters. Can only be invoked by a contract.
```
[main method] drops::create_sale(account: &signer, name: String,
description: String, start_time: u64, end_time: u64, count: u64,
template_id: u64, price: u64)
```

 - deletes the sale with the given id. Can only be invoked by a contract
```
[main method] drops::delete_sale(account: &signer, id: u64)
```

- buy a token from
this sale. The token is exchanged and sent to the buyer. The count field
of this sale is reduced by 1. If count = 0 at the time of calling the
buy() method, an error is returned.
```
[main method] drops::buy(buyer: &signer, id: u64)
```

- actually call buy() sount times. Condition for correct execution:
the count field of this sale \>= the count parameter
```
[main method] drops::buy_multiple(buyer: &signer, id: u64, count:
u64)
```

Methods listed below update the fields of the specified sale. They
can only be called by the contract owner

```
[main method] drops::update_sale_name(account: &signer, id: u64,
new_name: String)

[main method] drops::update_sale_description(account: &signer, id:
u64, new_description: String)

[main method] drops::update_sale_time(account: &signer, id: u64,
new_start_time: u64, new_end_time: u64)

[main method] drops::update_sale_count(account: &signer, id: u64,
new_count: u64)

[main method] drops::update_sale_price(account: &signer, id: u64,
new_price: u64)

[main method] drops::update_sale_template(account: &signer, id: u64,
new_template_id: u64)

[view method] drops::get_sales() - returns all undeleted drops/sales.
```

Example of a returned value drops::get_sales()

```
[
  {
    "count": "3",
    "description": "Pack contains 5 cards. \nPack chances: \n-c-Common 61.9% \n-r-Rare 31% \n-e-Epic 6% \n-l-Legendary 1% \n-m-Mythical 0.1% \n",
    "end_time": "0",
    "id": "1719398342847267",
    "name": "Changelings Pack",
    "price": "1000",
    "start_time": "0",
    "template_id": "355"
  },
  {
    "count": "0",
    "description": "descr",
    "end_time": "0",
    "id": "1719449413167866",
    "name": "test",
    "price": "1000",
    "start_time": "0",
    "template_id": "153"
  },
]
```

- returns the address on behalf of which this module mints tokens
```
[view method] drops::get_signer_obj_addr()
```


**JS examples of calling module methods**

Modules required to set up work with Aptos.

```
import { Aptos, AptosConfig, Network, Account, Ed25519PrivateKey} from
\"@aptos-labs/ts-sdk\";

const aptosConfig = new AptosConfig({ network: Network.TESTNET }); const
aptos = new Aptos(aptosConfig);

const module_address =
\"0x1ac6713de2cf42540ec69783ed0efe12e363fc0161653b9059008950d6bd0303\";
const owner_address =
\"0x1ac6713de2cf42540ec69783ed0efe12e363fc0161653b9059008950d6bd0303\";

const owner_private_key = new Ed25519PrivateKey(PRIVATE_KEY); const
owner_account = Account.fromPrivateKey({ privateKey: owner_private_key
});
```

How transactions are built and executed

Each transaction in the examples provided will be created using the
```transaction = aptos.transaction.build.simple()``` method. After that, the
same code will be called:

```
const senderAuth = await aptos.signAndSubmitTransaction({ signer:
owner_account, transaction }); const response = await
aptos.waitForTransaction({ transactionHash: senderAuth.hash, });
```

Note on View Methods. These methods do not need to create, sign and wait
for a transaction, but are called using aptos.view().

JS Code examples on how to use every module that is described.

1\. Templates

1\. template::get_template(template_id=100)

const unpackedTokens = await aptos.view({ payload: { function:
\`\${module_address}::templates::get_template\`, typeArguments: \[\],
functionArguments: \[100\], }, });

2\. Minting process

1\. minter::mint_template(account=owner_account, to=owner_address,
template_id=365) onst transaction = await
aptos.transaction.build.simple( { sender: owner_account.accountAddress,
data: { function: \`\${module_address}::minter::mint_template\`,
functionArguments: \[ owner_address, 355 \] } } );

3\. Staking

1\. staking::stake_tokens const transaction = await
aptos.transaction.build.simple( { sender: owner_account.accountAddress,
data: { function: \`\${module_address}::staking::stake_tokens\`,
functionArguments: \[ \[\"#11\", \"#9\"\] \] } } );

2\. staking::unstake_tokens const transaction = await
aptos.transaction.build.simple( { sender: owner_account.accountAddress,
data: { function: \`\${module_address}::staking::unstake_tokens\`,
functionArguments: \[ \[\"#11\", \"#9\"\] \] } } );

3\. staking::get_staked_tokens const unpackedTokens = await aptos.view({
payload: { function: \`\${module_address}::staking::get_staked_tokens\`,
typeArguments: \[\], functionArguments:
\[owner_account.accountAddress\], }, });

4\. Unpacking

1\. unpacking::unpack const transaction = await
aptos.transaction.build.simple( { sender: owner_account.accountAddress,
data: { function: \`\${module_address}::unpacking::unpack\`,
functionArguments: \[ pack_token_name \] } } );

2\. unpacking::claim const transaction = await
aptos.transaction.build.simple( { sender: owner_account.accountAddress,
data: { function: \`\${module_address}::unpacking::claim\`,
functionArguments: \[

\] } } );

3\. unpacking::get_unpacked_tokens const unpackedTokens = await
aptos.view({ payload: { function:
\`\${module_address}::unpacking::get_unpacked_tokens\`, typeArguments:
\[\], functionArguments: \[owner_account.accountAddress\], }, });

5\. Drops

1\. drops::create_sale const transaction = await
aptos.transaction.build.simple( { sender: owner_account.accountAddress,
data: { function: \`\${module_address}::drops::create_sale\`,
functionArguments: \[ \"test\", \"descr\", 0, 0, 4, 153, 1000 \] } } );

2\. drops::buy const transaction = await aptos.transaction.build.simple(
{ sender: not_owner_account.accountAddress, data: { function:
\`\${module_address}::drops::buy\`, functionArguments: \[ sale_id \] } }
);

3\. drops::buy_multiple const transaction = await
aptos.transaction.build.simple( { sender:
not_owner_account.accountAddress, data: { function:
\`\${module_address}::drops::buy_multiple\`, functionArguments: \[
sale_id, 4 \] } } );

4\. drops::get_sales const allSales = await aptos.view({ payload: {
function: \`\${module_address}::drops::get_sales\`, typeArguments: \[\],
functionArguments: \[\], }, });

5\. drops::update_sale_name const transaction = await
aptos.transaction.build.simple( { sender:
not_owner_account.accountAddress, data: { function:
\`\${module_address}::drops::update_sale_name\`, functionArguments: \[
sale_id, \"Some New Name\" \] } } );

6\. drops::delete_sale const transaction = await
aptos.transaction.build.simple( { sender:
not_owner_account.accountAddress, data: { function:
\`\${module_address}::drops::delete_sale\`, functionArguments: \[
sale_id \] } } );
