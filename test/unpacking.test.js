import { Aptos, AptosConfig, Network, Account, Ed25519PrivateKey } from "@aptos-labs/ts-sdk";
import { expect, should } from 'chai';
import { bcs, fromHEX } from "@mysten/bcs";

const aptosConfig = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(aptosConfig);

const devPrivateKey = new Ed25519PrivateKey('0x36500d266f4d229ab63e806a9e892cdef8af6c83dfc959c41b64cc59d7603a90');
const nonAuthPrivateKey = new Ed25519PrivateKey('0xe70cca98cc34a24807bc1cc2755f66233f83fa5d2fe26b4752731776f7bd69cc');

const devAccount = Account.fromPrivateKey({ privateKey: devPrivateKey });
const nonAuthAccount = Account.fromPrivateKey({ privateKey: nonAuthPrivateKey });

async function unpack(packName) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: devAccount.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::unpacking::unpack`,
                functionArguments: [packName]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: devAccount, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function claim() {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: devAccount.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::unpacking::claim`,
                functionArguments: []
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: devAccount, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function getUnpackedTokens(address) {
    const unpackedTokens = await aptos.view({
        payload: {
            function: `${devAccount.accountAddress}::unpacking::get_unpacked_tokens`,
            typeArguments: [],
            functionArguments: [address],
        },
    });

    return unpackedTokens[0];
}

async function getTemplateType(templateId) {
    const templateDataResults = await aptos.view({
        payload: {
            function: `${devAccount.accountAddress}::templates::get_template`,
            typeArguments: [],
            functionArguments: [templateId],
        },
    });

    const templateData = templateDataResults[0];

    if (templateData.property_names.length == 3)
    {
        return 'Card';
    }
    else
    {
        return 'Hero';
    }
}

async function mintToken(templateId) {
    const mintToAddress = devAccount.accountAddress;

    const transaction = await aptos.transaction.build.simple(
        {
            sender: devAccount.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::minter::mint_template`,
                functionArguments: [mintToAddress, templateId]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: devAccount, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    const events = await get_txn_events(senderAuth.hash);
    const lastMintedTokenName = events[0].data.name;

    return lastMintedTokenName;
}

async function get_txn_events(txnHash) {
    const url = `https://fullnode.testnet.aptoslabs.com/v1/transactions/by_hash/${txnHash}`;

    try {
        const response = await fetch(url);
        const transaction = await response.json();

        if (transaction.success) {
            const events = transaction.events;
            return events;
        } else {
            console.error('Transaction failed:', transaction.vm_status);
        }

    } catch (error) {
        console.error('Error fetching transaction:', error);
    }
}

let oldUnpackedTokens = undefined;
let newUnpackedTokens = undefined;

const cardsPackTemplateId = 355;
const heroesPackTemplateId = 356;

describe('unpack', () => {

    before(async function () {
        this.timeout(0);

        oldUnpackedTokens = await getUnpackedTokens(devAccount.accountAddress);
    })

    it('should allow to unpack pack you own', async function () {
        this.timeout(0);

        const packName = await mintToken(cardsPackTemplateId);
        await unpack(packName);
    })

    it('should NOT allow to unpack pack you DONT own', async function () {
        this.timeout(0);
        try {
            await unpack("#0");
        } catch (error) {
            const expectedError = 'Move abort in 0x3::token: EINSUFFICIENT_BALANCE(0x60005): Insufficient token balance';
            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })

    it('should update unpacked_tokens properly', async function () {
        this.timeout(0);

        newUnpackedTokens = await getUnpackedTokens(devAccount.accountAddress);

        expect(newUnpackedTokens.length - oldUnpackedTokens.length).to.equal(5);
    })

    it('should generate correct tokens for PackType = Card', async function () {
        this.timeout(0);

        const lastUnpackedTokens = newUnpackedTokens.slice(-5);
        
        for (let templateId of lastUnpackedTokens)
        {
            expect(await getTemplateType(templateId)).to.equal('Card');
        }
    })

    it.skip('should generate correct tokens for PackType = Heroes', async function () {
        this.timeout(0);

        const lastUnpackedTokens = newUnpackedTokens.slice(-5);
        
        for (let templateId of lastUnpackedTokens)
        {
            expect(await getTemplateType(templateId)).to.equal('Hero');
        }
    })
})

describe('claim', () => {
    it('should correctly claim unpacked tokens', async function () {
        this.timeout(0);

        await claim();
    })

    it('should update unpacked_tokens properly', async function () {
        this.timeout(0);

        newUnpackedTokens = await getUnpackedTokens(devAccount.accountAddress);
        expect(newUnpackedTokens.length).to.equal(0);
    })
})
