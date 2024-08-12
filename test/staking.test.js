import { Aptos, AptosConfig, Network, Account, Ed25519PrivateKey } from "@aptos-labs/ts-sdk";
import { expect, should } from 'chai';
import { bcs, fromHEX } from "@mysten/bcs";

const aptosConfig = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(aptosConfig);

const devPrivateKey = new Ed25519PrivateKey('0x36500d266f4d229ab63e806a9e892cdef8af6c83dfc959c41b64cc59d7603a90');
const nonAuthPrivateKey = new Ed25519PrivateKey('0xe70cca98cc34a24807bc1cc2755f66233f83fa5d2fe26b4752731776f7bd69cc');

const devAccount = Account.fromPrivateKey({ privateKey: devPrivateKey });
const nonAuthAccount = Account.fromPrivateKey({ privateKey: nonAuthPrivateKey });

async function stakeTokens(tokens) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: devAccount.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::staking::stake_tokens`,
                functionArguments: [tokens]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: devAccount, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function unstakeTokens(tokens) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: devAccount.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::staking::unstake_tokens`,
                functionArguments: [tokens]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: devAccount, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function getStakedTokens(address) {
    const stakedTokens = await aptos.view({
        payload: {
            function: `${devAccount.accountAddress}::staking::get_staked_tokens`,
            typeArguments: [],
            functionArguments: [address],
        },
    });

    return stakedTokens[0];
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

const collectionName = 'changelings';
const collectionCreatorAddress = '0x526b58b77d30bee6d9c7148cfba2cd5691cee3fe4e5e8b5c6db809679d42e83d';

async function doesOwnToken(address, tokenName) {
    const resourceType = '0x3::token::TokenStore';

    const tokenStore = await aptos.getAccountResource({
        accountAddress: address,
        resourceType: resourceType
    });

    const tokensTableHandle = tokenStore.tokens.handle;

    const tokenDataId = {
        creator: collectionCreatorAddress,
        collection: collectionName,
        name: tokenName
    }

    const tokenId = {
        token_data_id: tokenDataId,
        property_version: "0"
    };

    const tableItem = {
        key_type: "0x3::token::TokenId",
        value_type: "0x3::token::Token",
        key: tokenId
    }

    try {
        const tokenData = await aptos.getTableItem({
            handle: tokensTableHandle,
            data: tableItem
        });

        return true;
    } catch (error) {
        return false;
    }
}

const tokensToStake = ["#212", "#213"];
const tokensToUnstake = ["#212", "#213"];

let oldStakedTokens = undefined;
let newStakedTokens = undefined;

describe('stake_tokens', () => {
    it('should allow to stake tokens you own', async function () {
        this.timeout(0);

        oldStakedTokens = await getStakedTokens(devAccount.accountAddress);
        await stakeTokens(tokensToStake);
    })

    it('should NOT allow to stake tokens you DONT own', async function () {
        this.timeout(0);

        try {
            await stakeTokens(["#0", "#212"]);
        } catch (error) {
            const expectedError = 'Move abort in 0x3::token: EINSUFFICIENT_BALANCE(0x10005): Insufficient token balance';
            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })

    it('should stake correct tokens', async function () {
        this.timeout(0);

        newStakedTokens = await getStakedTokens(devAccount.accountAddress);
        const lastStakedTokens = newStakedTokens.slice(-tokensToStake.length);

        for (let i = 0; i < tokensToStake.length; i++)
        {
            expect(await doesOwnToken(devAccount.accountAddress, tokensToStake[i])).to.equal(false);
            expect(lastStakedTokens[i].name).to.equal(tokensToStake[i]);
        }
    })
})

describe('unstake_tokens', () => {
    it('should allow to unstake tokens you staked previously', async function () {
        this.timeout(0);

        await unstakeTokens(tokensToUnstake);
    })

    it('should NOT allow to stake tokens you DIDNT stake previously', async function () {
        this.timeout(0);

        try {
            await unstakeTokens(["#0"]);
        }
        catch (error) {
            const expectedError = 'Move abort in 0x3::token: EINSUFFICIENT_BALANCE(0x10005): Insufficient token balance';
            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })

    it('should unstake correct tokens', async function () {
        this.timeout(0);

        newStakedTokens = await getStakedTokens(devAccount.accountAddress);
        expect(newStakedTokens).to.eql(oldStakedTokens);

        for (let tokenName of tokensToUnstake)
        {
            expect(await doesOwnToken(devAccount.accountAddress, tokenName)).to.equal(true);
        }
    })
})