import { Aptos, AptosConfig, Network, Account, Ed25519PrivateKey, get } from "@aptos-labs/ts-sdk";
import { expect, should } from 'chai';
import { bcs, fromHEX } from "@mysten/bcs";

const aptosConfig = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(aptosConfig);

const tokenPrivateKey = new Ed25519PrivateKey('0x786834c326526ffffcb435312dc5ffee46367478afd6c366a3c1e0dd53e9fa8a');
const nonAuthPrivateKey = new Ed25519PrivateKey('0xe70cca98cc34a24807bc1cc2755f66233f83fa5d2fe26b4752731776f7bd69cc');

const tokenAccount = Account.fromPrivateKey({ privateKey: tokenPrivateKey });
const nonAuthAccount = Account.fromPrivateKey({ privateKey: nonAuthPrivateKey });

async function mint(amount, account) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: account.accountAddress,
            data: {
                function: `${tokenAccount.accountAddress}::sdm::mint`,
                functionArguments: [amount]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: account, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function burn(amount, account) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: account.accountAddress,
            data: {
                function: `${tokenAccount.accountAddress}::sdm::burn`,
                functionArguments: [amount]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: account, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function transfer(amount) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: tokenAccount.accountAddress,
            data: {
                function: `${tokenAccount.accountAddress}::sdm::transfer`,
                functionArguments: [nonAuthAccount.accountAddress, amount]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: tokenAccount, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function register(account) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: account.accountAddress,
            data: {
                function: `${tokenAccount.accountAddress}::sdm::register`,
                functionArguments: []
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: account, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

describe('mint', () => {
    it('should NOT allow NON authorized account to mint coins', async function () {
        this.timeout(0);

        try {
            await mint(1000, nonAuthAccount);
        } catch (error) {
            const expectedError = 'Move abort in 0xa425c664477b9dafde9a85e6e24fc948538a4586dc7db9301fb9aba75a1abda1::sdm: 0x1';
            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })

    it('should allow authorized account to mint coins', async function () {
        this.timeout(0);

        await mint(1000, tokenAccount);
    })
})

describe('burn', () => {
    it('should NOT allow NON authorized account to burn coins', async function () {
        this.timeout(0);

        try {
            await burn(1000, nonAuthAccount);
        } catch (error) {
            const expectedError = 'Move abort in 0xa425c664477b9dafde9a85e6e24fc948538a4586dc7db9301fb9aba75a1abda1::sdm: 0x1';
            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })

    it('should allow authorized account to burn coins', async function () {
        this.timeout(0);

        await mint(1000, tokenAccount);
    })
})

describe('register', () => {
    it('should register CoinStore for user', async function(){
        this.timeout(0);

        await register(nonAuthAccount);
    })
})

describe('transfer', () => {
    it('should transfer coins', async function () {
        this.timeout(0);

        await transfer(1000);
    })
})