import { ethers, assert } from 'hardhat';
import { HARDHAT_ACCOUNTS } from '../../hardhatAccounts.js';

import {
  DeterministicDeployFactory__factory,
  ERC20PresetMinterPauser,
  ERC20PresetMinterPauser__factory,
  VAnchorEncodeInputs__factory,
} from '@webb-tools/contracts';

import { getChainIdType } from '@webb-tools/utils';
import { PoseidonHasher, VAnchor } from '@webb-tools/anchors';
import { Deployer } from '@webb-tools/create2-utils';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Verifier } from '@webb-tools/anchors';
import { startGanacheServer } from '../startGanache';
import {
  MultiAssetVerifier,
  MultiAssetVAnchorTree,
  Registry,
  RegistryHandler,
  MultiFungibleTokenManager,
  MultiNftTokenManager,
  MultiAssetVAnchorProxy,
  SwapProofVerifier,
} from '@webb-tools/masp-anchors';
import {
  maspSwapFixtures,
  maspVAnchorFixtures,
} from '@webb-tools/protocol-solidity-extension-utils';
const maspVAnchorZkComponents = maspVAnchorFixtures('../../../solidity-fixtures/solidity-fixtures');
const maspSwapZkComponents = maspSwapFixtures('../../../solidity-fixtures/solidity-fixtures');

describe.only('Should deploy MASP contracts to the same address', () => {
  let deployer1: Deployer;
  let deployer2: Deployer;
  let token1: ERC20PresetMinterPauser;
  let token2: ERC20PresetMinterPauser;
  let poseidonHasher1: PoseidonHasher;
  let poseidonHasher2: PoseidonHasher;
  let sender: SignerWithAddress;
  const FIRST_CHAIN_ID = 31337;
  const SECOND_CHAIN_ID = 10000;
  let ganacheServer2: any;
  let ganacheProvider2 = new ethers.providers.JsonRpcProvider(
    `http://localhost:${SECOND_CHAIN_ID}`
  );
  ganacheProvider2.pollingInterval = 1;
  let ganacheWallet1 = new ethers.Wallet(HARDHAT_ACCOUNTS[1].privateKey, ganacheProvider2);
  let ganacheWallet2 = new ethers.Wallet(
    'c0d375903fd6f6ad3edafc2c5428900c0757ce1da10e5dd864fe387b32b91d7e',
    ganacheProvider2
  );
  const chainID1 = getChainIdType(FIRST_CHAIN_ID);
  const chainID2 = getChainIdType(SECOND_CHAIN_ID);

  before('setup networks', async () => {
    ganacheServer2 = await startGanacheServer(SECOND_CHAIN_ID, SECOND_CHAIN_ID, [
      {
        balance: '0x1000000000000000000000',
        secretKey: '0xc0d375903fd6f6ad3edafc2c5428900c0757ce1da10e5dd864fe387b32b91d7e',
      },
      {
        balance: '0x1000000000000000000000',
        secretKey: '0x' + HARDHAT_ACCOUNTS[1].privateKey,
      },
    ]);
    const signers = await ethers.getSigners();
    const wallet = signers[1];
    let hardhatNonce = await wallet.provider.getTransactionCount(wallet.address, 'latest');
    let ganacheNonce = await ganacheWallet1.provider.getTransactionCount(
      ganacheWallet1.address,
      'latest'
    );
    assert(ganacheNonce <= hardhatNonce);
    while (ganacheNonce < hardhatNonce) {
      ganacheWallet1.sendTransaction({
        to: ganacheWallet2.address,
        value: ethers.utils.parseEther('0.0'),
      });
      hardhatNonce = await wallet.provider.getTransactionCount(wallet.address, 'latest');
      ganacheNonce = await ganacheWallet1.provider.getTransactionCount(
        ganacheWallet1.address,
        'latest'
      );
    }
    assert.strictEqual(ganacheNonce, hardhatNonce);
    let b1 = await wallet.provider.getBalance(wallet.address);
    let b2 = await ganacheWallet1.provider.getBalance(ganacheWallet1.address);
    let b3 = await ganacheWallet2.provider.getBalance(ganacheWallet2.address);
    sender = wallet;
  });

  describe('#deploy common', () => {
    it('should deploy to the same address', async () => {
      let hardhatNonce = await sender.provider.getTransactionCount(sender.address, 'latest');
      let ganacheNonce = await ganacheWallet1.provider.getTransactionCount(
        ganacheWallet1.address,
        'latest'
      );
      while (ganacheNonce !== hardhatNonce) {
        if (ganacheNonce < hardhatNonce) {
          const Deployer2 = new DeterministicDeployFactory__factory(ganacheWallet1);
          let deployer2 = await Deployer2.deploy();
          await deployer2.deployed();
        } else {
          const Deployer1 = new DeterministicDeployFactory__factory(sender);
          let deployer1 = await Deployer1.deploy();
          await deployer1.deployed();
        }

        hardhatNonce = await sender.provider.getTransactionCount(sender.address, 'latest');
        ganacheNonce = await ganacheWallet1.provider.getTransactionCount(
          ganacheWallet1.address,
          'latest'
        );
        if (ganacheNonce === hardhatNonce) {
          break;
        }
      }
      assert.strictEqual(ganacheNonce, hardhatNonce);
      const Deployer1 = new DeterministicDeployFactory__factory(sender);
      let deployer1Contract = await Deployer1.deploy();
      await deployer1Contract.deployed();
      deployer1 = new Deployer(deployer1Contract);

      const Deployer2 = new DeterministicDeployFactory__factory(ganacheWallet1);
      let deployer2Contract = await Deployer2.deploy();
      await deployer2Contract.deployed();
      deployer2 = new Deployer(deployer2Contract);
      assert.strictEqual(deployer1.address, deployer2.address);
    });

    it('should deploy ERC20PresetMinterPauser to the same address using different wallets', async () => {
      const salt = '666';
      const saltHex = ethers.utils.id(salt);
      const argTypes = ['string', 'string'];
      const args = ['test token', 'TEST'];
      const { contract: contractToken1 } = await deployer1.deploy(
        ERC20PresetMinterPauser__factory,
        saltHex,
        sender,
        undefined,
        argTypes,
        args
      );
      token1 = contractToken1;
      const { contract: contractToken2 } = await deployer2.deploy(
        ERC20PresetMinterPauser__factory,
        saltHex,
        ganacheWallet2,
        undefined,
        argTypes,
        args
      );
      token2 = contractToken2;
      assert.strictEqual(token1.address, token2.address);
    });
    it('should deploy VAnchorEncodeInput library to the same address using same handler', async () => {
      const salt = '667';
      const saltHex = ethers.utils.id(salt);
      const { contract: contract1 } = await deployer1.deploy(
        VAnchorEncodeInputs__factory,
        saltHex,
        sender
      );
      const { contract: contract2 } = await deployer2.deploy(
        VAnchorEncodeInputs__factory,
        saltHex,
        ganacheWallet2
      );
      assert.strictEqual(contract1.address, contract2.address);
    });
    it('should deploy poseidonHasher to the same address using different wallets', async () => {
      const salt = '666';
      poseidonHasher1 = await PoseidonHasher.create2PoseidonHasher(deployer1, salt, sender);
      poseidonHasher2 = await PoseidonHasher.create2PoseidonHasher(deployer2, salt, ganacheWallet2);
      assert.strictEqual(poseidonHasher1.contract.address, poseidonHasher2.contract.address);
    });
  });
  describe('#deploy MASP VAnchor', () => {
    let maspVanchorVerifier1: MultiAssetVerifier;
    let maspVanchorVerifier2: MultiAssetVerifier;
    let swapVerifier1: SwapProofVerifier;
    let swapVerifier2: SwapProofVerifier;
    let registry1: Registry;
    let registry2: Registry;
    let registryHandler1: RegistryHandler;
    let registryHandler2: RegistryHandler;
    let multiFungibleTokenManager1: MultiFungibleTokenManager;
    let multiFungibleTokenManager2: MultiFungibleTokenManager;
    let multiNftTokenManager1: MultiNftTokenManager;
    let multiNftTokenManager2: MultiNftTokenManager;
    let maspProxy1: MultiAssetVAnchorProxy;
    let maspProxy2: MultiAssetVAnchorProxy;

    let salt = '666';

    it('should deploy verifiers to the same address using different wallets', async () => {
      assert.strictEqual(deployer1.address, deployer2.address);
      maspVanchorVerifier1 = await Verifier.create2Verifier(deployer1, salt, sender);
      maspVanchorVerifier2 = await Verifier.create2Verifier(deployer2, salt, ganacheWallet2);
      assert.strictEqual(
        maspVanchorVerifier1.contract.address,
        maspVanchorVerifier2.contract.address
      );
      let two1 = await SwapProofVerifier.create2Verifiers(deployer1, salt, sender);
      let two2 = await SwapProofVerifier.create2Verifiers(deployer2, salt, ganacheWallet2);
      let swapVerifier1 = await SwapProofVerifier.create2SwapProofVerifier(
        deployer1,
        salt,
        sender,
        two1.v2,
        two1.v8
      );
      let swapVerifier2 = await SwapProofVerifier.create2SwapProofVerifier(
        deployer2,
        salt,
        ganacheWallet2,
        two2.v2,
        two2.v8
      );
      assert.strictEqual(swapVerifier1.contract.address, swapVerifier2.contract.address);
    });

    it('should deploy MultiFungibleTokenManager to the same address using different wallets', async () => {
      multiFungibleTokenManager1 = await MultiFungibleTokenManager.create2MultiFungibleTokenManager(
        deployer1,
        salt,
        sender
      );
      multiFungibleTokenManager2 = await MultiFungibleTokenManager.create2MultiFungibleTokenManager(
        deployer2,
        salt,
        ganacheWallet2
      );
      assert.strictEqual(
        multiFungibleTokenManager1.contract.address,
        multiFungibleTokenManager2.contract.address
      );
    });

    it('should deploy the MultiNftTokenManager to the same address using different wallets', async () => {
      multiNftTokenManager1 = await MultiNftTokenManager.create2MultiNftTokenManager(
        deployer1,
        salt,
        sender
      );
      multiNftTokenManager2 = await MultiNftTokenManager.create2MultiNftTokenManager(
        deployer2,
        salt,
        ganacheWallet2
      );
      assert.strictEqual(
        multiNftTokenManager1.contract.address,
        multiNftTokenManager2.contract.address
      );
    });

    it('should deploy the MastProxy to the same address using different wallets', async () => {
      maspProxy1 = await MultiAssetVAnchorProxy.createMultiAssetVAnchorProxy(
        poseidonHasher1.contract.address,
        sender
      );
      maspProxy2 = await MultiAssetVAnchorProxy.createMultiAssetVAnchorProxy(
        poseidonHasher2.contract.address,
        sender
      );
      assert.strictEqual(maspProxy1.contract.address, maspProxy2.contract.address);
    });

    it('should deploy the registry to the same addrss using different wallets', async () => {
      registry1 = await Registry.create2Registry(deployer1, salt, sender);
      registry2 = await Registry.create2Registry(deployer1, salt, ganacheWallet2);

      let dummyBridgeSigner = await ethers.getSigners()[4];
      registryHandler1 = await RegistryHandler.createRegistryHandler(
        await dummyBridgeSigner.getAddress(),
        [await registry1.createResourceId()],
        [registry1.contract.address],
        dummyBridgeSigner
      );
      registryHandler2 = await RegistryHandler.createRegistryHandler(
        await dummyBridgeSigner.getAddress(),
        [await registry2.createResourceId()],
        [registry2.contract.address],
        dummyBridgeSigner
      );
      assert.strictEqual(registryHandler1.contract.address, registryHandler2.contract.address);
    });

    it('should deploy VAnchor to the same address using different wallets (but same handler) ((note it needs previous test to have run))', async () => {
      const levels = 30;
      const saltHex = ethers.utils.id(salt);
      assert.strictEqual(
        maspVanchorVerifier1.contract.address,
        maspVanchorVerifier2.contract.address
      );
      assert.strictEqual(poseidonHasher1.contract.address, poseidonHasher2.contract.address);
      assert.strictEqual(token1.address, token2.address);
      let dummyHandlerAddress = await (await ethers.getSigners())[5].getAddress();
      let zkComponents2_2 = await maspVAnchorZkComponents[22]();
      let zkComponents16_2 = await maspVAnchorZkComponents[162]();
      let swapCircuitZkComponents = await maspSwapZkComponents[220]();
      const vanchor1 = await MultiAssetVAnchorTree.create2MultiAssetVAnchorTree(
        deployer1,
        salt,
        registry1.contract.address,
        maspVanchorVerifier1.contract.address,
        swapVerifier1.contract.address,
        dummyHandlerAddress,
        poseidonHasher1.contract.address,
        maspProxy1.contract.address,
        levels,
        1,
        zkComponents2_2,
        zkComponents16_2,
        swapCircuitZkComponents,
        sender
      );
      const vanchor2 = await MultiAssetVAnchorTree.create2MultiAssetVAnchorTree(
        deployer2,
        salt,
        registry2.contract.address,
        maspVanchorVerifier2.contract.address,
        swapVerifier2.contract.address,
        dummyHandlerAddress,
        poseidonHasher2.contract.address,
        maspProxy2.contract.address,
        levels,
        1,
        zkComponents2_2,
        zkComponents16_2,
        swapCircuitZkComponents,
        ganacheWallet2
      );
      assert.strictEqual(vanchor1.contract.address, vanchor2.contract.address);
    });
  });
  after('terminate networks', async () => {
    await ganacheServer2.close();
  });
});
