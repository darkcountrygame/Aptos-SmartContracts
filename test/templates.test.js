import { Aptos, AptosConfig, Network, Account, Ed25519PrivateKey, isNumber } from "@aptos-labs/ts-sdk";
import { expect } from 'chai';
import { bcs, fromHEX } from "@mysten/bcs";

const aptosConfig = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(aptosConfig);

const devPrivateKey = new Ed25519PrivateKey('0x36500d266f4d229ab63e806a9e892cdef8af6c83dfc959c41b64cc59d7603a90');
const nonAuthPrivateKey = new Ed25519PrivateKey('0xe70cca98cc34a24807bc1cc2755f66233f83fa5d2fe26b4752731776f7bd69cc');

const devAccount = Account.fromPrivateKey({ privateKey: devPrivateKey });
const nonAuthAccount = Account.fromPrivateKey({ privateKey: nonAuthPrivateKey });


describe('add_template', () => {
    it('should allow authorized account to add new template', async function () {

        this.timeout(0);

        const newTemplateData = {
            template_id: 1000,
            name: "New Test Template",
            description: "New Test Description",
            uri: "Some uri",
            property_names: ["param1", "param2", "param3"],
            property_values: ["111", "hello", "some"]
        };

        const transaction = await aptos.transaction.build.simple(
            {
                sender: devAccount.accountAddress,
                data: {
                    function: `${devAccount.accountAddress}::templates::add_template`,
                    functionArguments: Object.values(newTemplateData)
                }
            }
        );

        const senderAuth = await aptos.signAndSubmitTransaction({ signer: devAccount, transaction });
        const response = await aptos.waitForTransaction({
            transactionHash: senderAuth.hash,
        });

    })

    it('should NOT allow NON authorized account to add new template', async function () {

        this.timeout(0);

        try {
            const newTemplateData = {
                template_id: 1000,
                name: "New Test Template",
                description: "New Test Description",
                uri: "Some uri",
                property_names: ["param1", "param2", "param3"],
                property_values: ["111", "hello", "some"]
            };

            const transaction = await aptos.transaction.build.simple(
                {
                    sender: nonAuthAccount.accountAddress,
                    data: {
                        function: `${devAccount.accountAddress}::templates::add_template`,
                        functionArguments: Object.values(newTemplateData)
                    }
                }
            );

            const senderAuth = await aptos.signAndSubmitTransaction({ signer: nonAuthAccount, transaction });
            const response = await aptos.waitForTransaction({
                transactionHash: senderAuth.hash,
            });
        } catch (error) {
            const expectedErrorCode = '0x1';
            const expectedError = `Move abort in ${devAccount.accountAddress}::templates: ${expectedErrorCode}`;

            expect(error.transaction.vm_status).to.equal(expectedError);
        }
    })
})

describe('get_template', () => {
    it('should return valid data for TemplateID = 1000', async function () {

        this.timeout(0);

        const templateId = 1000;

        const templateDataResults = await aptos.view({
            payload: {
                function: `${devAccount.accountAddress}::templates::get_template`,
                typeArguments: [],
                functionArguments: [templateId],
            },
        });

        const templateData = templateDataResults[0];

        const expectedTemplateData = {
            template_id: "1000",
            name: "New Test Template",
            description: "New Test Description",
            uri: "Some uri",
            property_names: ["param1", "param2", "param3"],
            property_types: ["0x1::string::String", "0x1::string::String", "0x1::string::String"],
            property_values: ["111", "hello", "some"]
        };

        expect(templateData.id).to.equal(expectedTemplateData.template_id);
        expect(templateData.name).to.equal(expectedTemplateData.name);
        expect(templateData.description).to.equal(expectedTemplateData.description);
        expect(templateData.uri).to.equal(expectedTemplateData.uri);
        expect(templateData.property_names).to.eql(expectedTemplateData.property_names);
        expect(templateData.property_types).to.eql(expectedTemplateData.property_types);

        const decodedValues = templateData.property_values_bytes.map((hexData) => bcs.string().parse(fromHEX(hexData)));

        expect(decodedValues).to.eql(expectedTemplateData.property_values);
    })
})