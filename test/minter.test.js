import { Aptos, AptosConfig, Network, Account, Ed25519PrivateKey } from "@aptos-labs/ts-sdk";
import { expect, should } from 'chai';
import { bcs, fromHEX } from "@mysten/bcs";

const aptosConfig = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(aptosConfig);

const devPrivateKey = new Ed25519PrivateKey('0x36500d266f4d229ab63e806a9e892cdef8af6c83dfc959c41b64cc59d7603a90');
const nonAuthPrivateKey = new Ed25519PrivateKey('0xe70cca98cc34a24807bc1cc2755f66233f83fa5d2fe26b4752731776f7bd69cc');

const devAccount = Account.fromPrivateKey({ privateKey: devPrivateKey });
const nonAuthAccount = Account.fromPrivateKey({ privateKey: nonAuthPrivateKey });

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

async function getTokenData(tokenName, collectionName, collectionCreatorAddress) {
    const resourceType = '0x3::token::Collections';

    const collections = await aptos.getAccountResource({
        accountAddress: collectionCreatorAddress,
        resourceType: resourceType
    });

    const tokenDataTableHandle = collections.token_data.handle;

    const tokenDataId = {
        creator: collectionCreatorAddress,
        collection: collectionName,
        name: tokenName
    }

    const tableItem = {
        key_type: "0x3::token::TokenDataId",
        value_type: "0x3::token::TokenData",
        key: tokenDataId
    }

    const tokenData = await aptos.getTableItem({
        handle: tokenDataTableHandle,
        data: tableItem
    });

    return tokenData;
}

let lastMintedTokenName = undefined;

const templateId = 355;

const collectionName = 'changelings';
const collectionCreatorAddress = '0x526b58b77d30bee6d9c7148cfba2cd5691cee3fe4e5e8b5c6db809679d42e83d';

describe('mint_template', () => {
    it('should allow authorized account to mint tokens with correct TemplateID', async function () {
        this.timeout(0);

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
        lastMintedTokenName = events[0].data.name;
    })

    it('should mint token with correct attributes', async function () {
        const tokenData = await getTokenData(lastMintedTokenName, collectionName, collectionCreatorAddress);

        const templateDataResults = await aptos.view({
            payload: {
                function: `${devAccount.accountAddress}::templates::get_template`,
                typeArguments: [],
                functionArguments: [templateId],
            },
        });

        const templateData = templateDataResults[0];

        const extractKeys = (item) => item.key;
        const extractValues = (item) => item.value.value;

        const tokenAttributesKeys = tokenData.default_properties.map.data.map(extractKeys);
        const tokenAttributesValues = tokenData.default_properties.map.data.map(extractValues);

        const tokenBurnKey = tokenAttributesKeys.pop();
        const tokenTemplateIdKey = tokenAttributesKeys.pop();

        const tokenBurnValue = tokenAttributesValues.pop();
        const tokenTemplateIdValue = bcs.u64().parse(fromHEX(tokenAttributesValues.pop()));

        expect(tokenBurnKey).to.equal('TOKEN_BURNABLE_BY_OWNER');
        expect(tokenBurnValue).to.equal('0x01')

        expect(tokenTemplateIdKey).to.equal('Template');
        expect(+tokenTemplateIdValue).to.equal(templateId);

        expect(tokenData.name).to.equal(lastMintedTokenName);
        expect(tokenData.description).to.equal(templateData.description);
        expect(tokenData.uri).to.equal(templateData.uri);
        expect(tokenAttributesKeys).to.eql(templateData.property_names);
        expect(tokenAttributesValues).to.eql(templateData.property_values_bytes);
    })

    it('should NOT allow NON authorized account to mint tokens with correct TemplateID', async function () {
        this.timeout(0);

        try {
            const mintToAddress = devAccount.accountAddress;

            const transaction = await aptos.transaction.build.simple(
                {
                    sender: nonAuthAccount.accountAddress,
                    data: {
                        function: `${devAccount.accountAddress}::minter::mint_template`,
                        functionArguments: [mintToAddress, templateId]
                    }
                }
            );

            const senderAuth = await aptos.signAndSubmitTransaction({ signer: nonAuthAccount, transaction });
            const response = await aptos.waitForTransaction({
                transactionHash: senderAuth.hash,
            })
        } catch (error) {
            const expectedErrorCode = '0x1';
            const expectedError = `Move abort in ${devAccount.accountAddress}::minter: ${expectedErrorCode}`;

            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })

    it('should NOT allow authorized account to mint tokens with NOT correct TemplateID', async function () {
        this.timeout(0);

        try {
            const incorrectTemplateId = 100000;
            const mintToAddress = devAccount.accountAddress;

            const transaction = await aptos.transaction.build.simple(
                {
                    sender: nonAuthAccount.accountAddress,
                    data: {
                        function: `${devAccount.accountAddress}::minter::mint_template`,
                        functionArguments: [mintToAddress, incorrectTemplateId]
                    }
                }
            );

            const senderAuth = await aptos.signAndSubmitTransaction({ signer: nonAuthAccount, transaction });
            const response = await aptos.waitForTransaction({
                transactionHash: senderAuth.hash,
            })
        } catch (error) {
            const expectedErrorCode = '0x1';
            const expectedError = `Move abort in ${devAccount.accountAddress}::minter: ${expectedErrorCode}`;

            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })
})