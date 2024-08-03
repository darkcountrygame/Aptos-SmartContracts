module token::sdm {

    use aptos_framework::coin::{Self};
    use aptos_framework::managed_coin;
    use std::signer;
    use std::string;

    struct SDM {}

    struct TokenCaps has key {
        burn_cap: coin::BurnCapability<SDM>,
        freeze_cap: coin::FreezeCapability<SDM>,
        mint_cap: coin::MintCapability<SDM>
    }

    public entry fun init(deployer: &signer) {       

        assert!(@token == signer::address_of(deployer), 1);

        let (
            burn_cap, 
            freeze_cap, 
            mint_cap
        ) = coin::initialize<SDM>(
            deployer,
            string::utf8(b"ShadowDimes"),
            string::utf8(b"SDM"),
            4,
            true,
        );

        let deployer_addr = signer::address_of(deployer);
        coin::register<SDM>(deployer);

        move_to(deployer, TokenCaps{
            burn_cap,
            freeze_cap,
            mint_cap
        }
        );
    }

    public entry fun transfer(account: &signer, to: address, amount: u64)
    {
        coin::transfer<SDM>(account, to, amount);
    }

    public entry fun register(account: &signer)
    {
        coin::register<SDM>(account);
    }

    public entry fun mint(account: &signer, amount: u64) acquires TokenCaps
    {
        assert!(@token == signer::address_of(account), 1);
        let token_caps = borrow_global<TokenCaps>(@token);
        let coins_minted = coin::mint(amount, &token_caps.mint_cap);
        coin::deposit(@token, coins_minted);
    }

    public entry fun burn(account: &signer, amount: u64) acquires TokenCaps
    {
        assert!(@token == signer::address_of(account), 1);
        let token_caps = borrow_global<TokenCaps>(@token);
        coin::burn_from(@token, amount, &token_caps.burn_cap);
    }
}