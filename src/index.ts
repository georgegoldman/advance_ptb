import { SuiGrpcClient } from "@mysten/sui/grpc";
import { deepbook } from "@mysten/deepbook-v3";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import dotenv from "dotenv";
dotenv.config();

const _keypair = Ed25519Keypair.fromSecretKey(process.env.PK!);

const grpcClient = new SuiGrpcClient({
  network: "testnet",
  baseUrl: "https://fullnode.testnet.sui.io:443",
}).$extend(
  deepbook({
    address: _keypair.getPublicKey().toSuiAddress().toString(),
    balanceManagers: {},
  }),
);

const tx = new Transaction();

async function programmableTransactionBlock(tx: Transaction) {
  const coins = await grpcClient.listCoins({
    owner: "0xa35de887586ac1a9e644bc8f1b24a0d54c6eea66b8feef8bfd94297adde8d479",
    coinType:
      "0xa1ec7fc00a6f40db9693ad1415d0c193ad3906494428cf252621037bd7117e29::usdc::USDC",
  });

  const accounts = [
    "0x8ccf6fecdb03b838efb46d586940f426ad974d82a5e84a357a79bea4f04c1c1b",
    "0x0cbb67a860b8d468a2984100816eaa94a2bcea4f0ee5e509a6ca0d0779e42b34",
    "0xa35de887586ac1a9e644bc8f1b24a0d54c6eea66b8feef8bfd94297adde8d479",
    "0x5afdf4cbcaf64613bed1e2037f4fd83a35d230994f92c6aac171c07913dcef48",
    "0x57f0b80d3b388b3a3260cc76eb651a3284a85c54c46143b53d187bcc012cbc94",
    "0x551bedcbc17a5b243273e142156b0656c8750e1a3e216f1329c010793c9efdd7",
  ];

  const account_split_corresponding_equivalent = accounts.map(() =>
    tx.pure.u64(2000000),
  );

  if (!coins.objects.length) {
    throw new Error("No Coin found");
  }

  const coin_from_spliting = tx.splitCoins(
    tx.object(coins.objects[0]!.objectId),
    account_split_corresponding_equivalent,
  );

  accounts.forEach((account, index) =>
    tx.transferObjects([coin_from_spliting[index]!], tx.pure.address(account)),
  );

  const result = await grpcClient.signAndExecuteTransaction({
    transaction: tx,
    signer: _keypair,
    include: {
      effects: true,
    },
  });

  console.log(result.Transaction);
}

async function deebPTB(tx: Transaction) {
  const borrowAmount = 1;
  const [deepcoin, flashLoan] = tx.add(
    grpcClient.deepbook.flashLoans.borrowBaseAsset("DEEP_SUI", borrowAmount),
  );

  const [baseOut, quoteOut, deepOut] = tx.add(
    grpcClient.deepbook.deepBook.swapExactQuoteForBase({
      poolKey: "SUI_DBUSDC",
      amount: 0.5,
      deepAmount: 1,
      minOut: 0,
      deepCoin: deepcoin,
    }),
  );

  tx.transferObjects(
    [baseOut, quoteOut, deepOut],
    _keypair.getPublicKey().toSuiAddress().toString(),
  );

  const [baseOut2, quoteOut2, deepOut2] = tx.add(
    grpcClient.deepbook.deepBook.swapExactQuoteForBase({
      poolKey: "SUI_DBUSDC",
      amount: 10,
      deepAmount: 0,
      minOut: 0,
      deepCoin: deepcoin,
    }),
  );

  tx.transferObjects(
    [quoteOut2, deepOut2],
    _keypair.getPublicKey().toSuiAddress().toString(),
  );

  const loanRemain = tx.add(
    grpcClient.deepbook.flashLoans.returnBaseAsset(
      "DEEP_SUI",
      borrowAmount,
      baseOut2,
      flashLoan,
    ),
  );

  tx.transferObjects(
    [loanRemain],
    _keypair.getPublicKey().toSuiAddress().toString(),
  );

  const result = await grpcClient.signAndExecuteTransaction({
    transaction: tx,
    signer: _keypair,
    include: {
      effects: true,
    },
  });

  console.log(result.Transaction);
}

await deebPTB(tx);
