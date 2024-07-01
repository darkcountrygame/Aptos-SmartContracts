import { Aptos, AptosConfig, Network, Account, Ed25519PrivateKey, isNumber } from "@aptos-labs/ts-sdk";

import { expect } from 'chai';

const aptosConfig = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(aptosConfig);

const module_address = "0x1ac6713de2cf42540ec69783ed0efe12e363fc0161653b9059008950d6bd0303";
const owner_address = "0x1ac6713de2cf42540ec69783ed0efe12e363fc0161653b9059008950d6bd0303";

const owner_private_key = new Ed25519PrivateKey(PRIVATE_KEY);
const owner_account = Account.fromPrivateKey({ privateKey: owner_private_key });

const not_owner_private_key = new Ed25519PrivateKey(NOW_OWNER_PRIVATE_KEY)
const not_owner_account = Account.fromPrivateKey({ privateKey: not_owner_private_key })

let pack_token_name = "#681"


describe("Token Minting", () => {
  it("Correct Mint", async function () {

    this.timeout(5000)
    const transaction = await aptos.transaction.build.simple(
      {
        sender: owner_account.accountAddress,
        data: {
          function: `${module_address}::minter::mint_template`,
          functionArguments: [
            owner_address,
            355
          ]
        }
      }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: owner_account, transaction });
    const response = await aptos.waitForTransaction({
      transactionHash: senderAuth.hash,
    });
  }
  )

  it("Incorrect Template ID", async function () {

    this.timeout(5000)
    async function IncorrectMintId() {
      const transaction = await aptos.transaction.build.simple(
        {
          sender: owner_account.accountAddress,
          data: {
            function: `${module_address}::minter::mint_template`,
            functionArguments: [
              owner_account.accountAddress,
              50000
            ]
          }
        }
      );

      const senderAuth = await aptos.signAndSubmitTransaction({ signer: owner_account, transaction });
      const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
      });
    }

    try {
      await IncorrectMintId();
      throw "Not Passed"
    } catch (err) {
      expect(err).to.not.equal("Not Passed")
      const expected_status = "Move abort in 0x1::table: 0x6507"
      expect(err.transaction.vm_status).to.equal(expected_status)
    }
  }
  )

  it("Incorrect Authority", async function () {

    this.timeout(5000)
    async function IncorrectMintAuth() {
      const transaction = await aptos.transaction.build.simple(
        {
          sender: not_owner_account.accountAddress,
          data: {
            function: `${module_address}::minter::mint_template`,
            functionArguments: [
              not_owner_account.accountAddress,
              100
            ]
          }
        }
      );

      const senderAuth = await aptos.signAndSubmitTransaction({ signer: not_owner_account, transaction });
      const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
      });
    }

    try {
      await IncorrectMintAuth();
      throw "Not Passed"
    } catch (err) {
      expect(err).to.not.equal("Not Passed")
      const expected_status = "Move abort in 0x1ac6713de2cf42540ec69783ed0efe12e363fc0161653b9059008950d6bd0303::minter: 0x1"
      expect(err.transaction.vm_status).to.equal(expected_status)
    }
  }
  )

})

describe("Token Staking", () => {
  it("Stake", async function () {

    this.timeout(5000)
    

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: owner_account, transaction });
    const response = await aptos.waitForTransaction({
      transactionHash: senderAuth.hash,
    });

    //check get_staked_tokens
    const unpackedTokens = await aptos.view({
      payload: {
        function: `${module_address}::staking::get_staked_tokens`,
        typeArguments: [],
        functionArguments: [owner_account.accountAddress],
      },
    });

    expect(unpackedTokens[0][0].name).to.equal("#11")
    expect(unpackedTokens[0][1].name).to.equal("#9")

  })


  it("Unstake", async function () {
    this.timeout(5000)
    const transaction = await aptos.transaction.build.simple(
      {
        sender: owner_account.accountAddress,
        data: {
          function: `${module_address}::staking::unstake_tokens`,
          functionArguments: [
            ["#11", "#9"]
          ]
        }
      }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: owner_account, transaction });
    const response = await aptos.waitForTransaction({
      transactionHash: senderAuth.hash,
    });

    //check get_staked_tokens
    const unpackedTokens = await aptos.view({
      payload: {
        function: `${module_address}::staking::get_staked_tokens`,
        typeArguments: [],
        functionArguments: [owner_account.accountAddress],
      },
    });

    expect(unpackedTokens[0].length).to.equal(0)
  })

})

describe("Unpacking", () => {
  it("Unpack", async function () {

    this.timeout(5000);

    const transaction = await aptos.transaction.build.simple(
      {
        sender: owner_account.accountAddress,
        data: {
          function: `${module_address}::unpacking::unpack`,
          functionArguments: [
            pack_token_name
          ]
        }
      }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: owner_account, transaction });
    const response = await aptos.waitForTransaction({
      transactionHash: senderAuth.hash,
    });

    //check get_unpacked_tokens
    const unpackedTokens = await aptos.view({
      payload: {
        function: `${module_address}::unpacking::get_unpacked_tokens`,
        typeArguments: [],
        functionArguments: [owner_account.accountAddress],
      },
    });

    expect(unpackedTokens[0].length).to.equal(5)
  })

  it("Claim", async () => {
    const transaction = await aptos.transaction.build.simple(
      {
        sender: owner_account.accountAddress,
        data: {
          function: `${module_address}::unpacking::claim`,
          functionArguments: [

          ]
        }
      }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: owner_account, transaction });
    const response = await aptos.waitForTransaction({
      transactionHash: senderAuth.hash,
    });

    //check get_unpacked_tokens
    const unpackedTokens = await aptos.view({
      payload: {
        function: `${module_address}::unpacking::get_unpacked_tokens`,
        typeArguments: [],
        functionArguments: [owner_account.accountAddress],
      },
    });

    expect(unpackedTokens[0].length).to.equal(0)
  })
})


let sale_id = 0

describe("Buy tokens", () => {

  it("Create sale", async function () {
    this.timeout(5000);

    const transaction = await aptos.transaction.build.simple(
      {
        sender: owner_account.accountAddress,
        data: {
          function: `${module_address}::drops::create_sale`,
          functionArguments: [
            "test", "descr", 0, 0, 4, 153, 1000
          ]
        }
      }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: owner_account, transaction });
    const response = await aptos.waitForTransaction({
      transactionHash: senderAuth.hash,
    });

    const allSales = await aptos.view({
      payload: {
        function: `${module_address}::drops::get_sales`,
        typeArguments: [],
        functionArguments: [],
      },
    });

    const numberOfSales = allSales[0].length
    sale_id = +allSales[0][numberOfSales - 1].id
  })

  it("Buy 1 token", async function () {
    this.timeout(5000);

    const transaction = await aptos.transaction.build.simple(
      {
        sender: not_owner_account.accountAddress,
        data: {
          function: `${module_address}::drops::buy`,
          functionArguments: [
            sale_id
          ]
        }
      }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: not_owner_account, transaction });
    const response = await aptos.waitForTransaction({
      transactionHash: senderAuth.hash,
    });
  })

  it("Incorrect sale_id", async function () {
    this.timeout(5000);

    async function try_buy() {
      const transaction = await aptos.transaction.build.simple(
        {
          sender: not_owner_account.accountAddress,
          data: {
            function: `${module_address}::drops::buy`,
            functionArguments: [
              0
            ]
          }
        }
      );

      const senderAuth = await aptos.signAndSubmitTransaction({ signer: not_owner_account, transaction });
      const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
      });
    }

    try {
      await try_buy()
    } catch (err) {
      const expected_status = 'Move abort in 0x1ac6713de2cf42540ec69783ed0efe12e363fc0161653b9059008950d6bd0303::drops: 0x2'
      expect(err.transaction.vm_status).to.equal(expected_status)
    }

  })

  it("Incorrect buy amount (try 4)", async function () {
    this.timeout(5000);

    async function try_buy() {
      const transaction = await aptos.transaction.build.simple(
        {
          sender: not_owner_account.accountAddress,
          data: {
            function: `${module_address}::drops::buy_multiple`,
            functionArguments: [
              sale_id, 4
            ]
          }
        }
      );

      const senderAuth = await aptos.signAndSubmitTransaction({ signer: not_owner_account, transaction });
      const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
      });
    }

    try {
      await try_buy()
    } catch (err) {
      const expected_status = 'Move abort in 0x1ac6713de2cf42540ec69783ed0efe12e363fc0161653b9059008950d6bd0303::drops: 0x2'
      expect(err.transaction.vm_status).to.equal(expected_status)
    }
  })

  it("Buy 3 tokens", async function () {
    const transaction = await aptos.transaction.build.simple(
      {
        sender: not_owner_account.accountAddress,
        data: {
          function: `${module_address}::drops::buy_multiple`,
          functionArguments: [
            sale_id, 3
          ]
        }
      }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: not_owner_account, transaction });
    const response = await aptos.waitForTransaction({
      transactionHash: senderAuth.hash,
    });
  })
})
