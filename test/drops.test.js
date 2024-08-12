import { Aptos, AptosConfig, Network, Account, Ed25519PrivateKey, get } from "@aptos-labs/ts-sdk";
import { expect, should } from 'chai';
import { bcs, fromHEX } from "@mysten/bcs";

const aptosConfig = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(aptosConfig);

const devPrivateKey = new Ed25519PrivateKey('0x36500d266f4d229ab63e806a9e892cdef8af6c83dfc959c41b64cc59d7603a90');
const nonAuthPrivateKey = new Ed25519PrivateKey('0xe70cca98cc34a24807bc1cc2755f66233f83fa5d2fe26b4752731776f7bd69cc');

const devAccount = Account.fromPrivateKey({ privateKey: devPrivateKey });
const nonAuthAccount = Account.fromPrivateKey({ privateKey: nonAuthPrivateKey });

async function create_sale(saleData) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: devAccount.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::drops::create_sale`,
                functionArguments: saleData
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: devAccount, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function buy(saleId) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: devAccount.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::drops::buy`,
                functionArguments: [saleId]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: devAccount, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function buy_multiple(saleId, count) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: devAccount.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::drops::buy_multiple`,
                functionArguments: [saleId, count]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: devAccount, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function delete_sale(saleId, account) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: account.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::drops::delete_sale`,
                functionArguments: [saleId]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: account, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function update_sale_name(saleId, newName, account) {
    const transaction = await aptos.transaction.build.simple(
        {
            sender: account.accountAddress,
            data: {
                function: `${devAccount.accountAddress}::drops::update_sale_name`,
                functionArguments: [saleId, newName]
            }
        }
    );

    const senderAuth = await aptos.signAndSubmitTransaction({ signer: account, transaction });
    const response = await aptos.waitForTransaction({
        transactionHash: senderAuth.hash,
    });

    return senderAuth.hash
}

async function get_sales() {
    const salesResults = await aptos.view({
        payload: {
            function: `${devAccount.accountAddress}::drops::get_sales`,
            typeArguments: [],
            functionArguments: [],
        },
    });

    return salesResults[0];
}

let lastCreatedSaleId = undefined;
let oldSales = undefined;

describe('create_sale', () => {
    it('should allow to create sale', async function () {
        this.timeout(0);

        oldSales = await get_sales();

        const saleData = {
            name: "Test Sale Name",
            description: "Test Sale Description",
            start_time: 0,
            end_time: 0,
            count: 10,
            template_id: 100,
            price: 1000,
            token_type: "APT"
        };

        const txnHash = await create_sale(Object.values(saleData));
    })

    it('should add newly created sale to the list of sales', async function () {
        this.timeout(0);

        const newSales = await get_sales();

        const lastSale = newSales.pop();
        lastCreatedSaleId = lastSale.id;
    })
})

describe('update sale', () => {
    it('should allow authorized account to update sale name', async function () {
        this.timeout(0);

        await update_sale_name(lastCreatedSaleId, "New Name", devAccount);
    })

    it('should NOT allow NON authorized account to update sale name', async function () {
        this.timeout(0);

        try {
            await update_sale_name(lastCreatedSaleId, "New Name", nonAuthAccount);
        } catch (error) {
            const expectedError = 'Move abort in 0x2de6aea32fcb7ab2e33ab9a78df3b5f4ef5b718ef77475f96ed8a66f466afc28::drops: 0x1';
            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })
})

describe('buy', () => {
    it('should allow to buy and existing sale', async function () {
        this.timeout(0);

        await buy(lastCreatedSaleId);
    })

    it('should NOT allow buying NOT existing sale', async function () {
        this.timeout(0);

        try {
            await buy(0);
        } catch (error) {
            const expectedError = 'Move abort in 0x2de6aea32fcb7ab2e33ab9a78df3b5f4ef5b718ef77475f96ed8a66f466afc28::drops: 0x2';
            expect(error.transaction.vm_status).to.equal(expectedError)
        }
    })

    it('should allow to buy multiple', async function () {
        this.timeout(0);

        await buy_multiple(lastCreatedSaleId, 3);
    })
})

describe('delete_sale', () => {
    it('should NOT allow NON authorized account to delete sale', async function () {
        this.timeout(0);

        try {
            await delete_sale(lastCreatedSaleId, nonAuthAccount);
        } catch (error) {
            const expectedError = 'Move abort in 0x2de6aea32fcb7ab2e33ab9a78df3b5f4ef5b718ef77475f96ed8a66f466afc28::drops: 0x1';
            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })

    it('should allow authorized account to delete sale', async function () {
        this.timeout(0);

        await delete_sale(lastCreatedSaleId, devAccount);
    })

    it('should update sales properly', async function () {
        this.timeout(0);

        const newSales = await get_sales();

        expect(newSales).to.eql(oldSales);
    })
})