// deploy/deploy.ts
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy, execute, read, log, getArtifact } = deployments;
  const { deployer } = await getNamedAccounts();

  const envFQN = process.env.FQN?.trim(); // опционально: точный FQN артефакта
  const waitConfirmations = Number(process.env.WAIT_CONFIRMATIONS ?? 1);

  // ── 1) Поиск артефакта ─────────────────────────────────────────────
  const candidates: string[] = [
    ...(envFQN ? [envFQN] : []),
    "SecretColorVote",
    "contracts/SecretColorVote.sol:SecretColorVote",
    "contracts/vote/SecretColorVote.sol:SecretColorVote",
    "src/SecretColorVote.sol:SecretColorVote",
  ];

  let contractId: string | null = null;
  for (const c of candidates) {
    try {
      await getArtifact(c);
      contractId = c;
      break;
    } catch {}
  }
  if (!contractId) {
    throw new Error(
      `Cannot find artifact for SecretColorVote. Try one of: ${candidates.join(", ")}. ` +
        `Make sure the contract is compiled.`,
    );
  }

  // ── 2) Конструктор: число категорий ─────────────────────────────────
  const NUM_CATEGORIES_RAW = process.env.NUM_CATEGORIES ?? "4";
  const numCategories = Number(NUM_CATEGORIES_RAW);
  if (!Number.isInteger(numCategories) || numCategories < 1 || numCategories > 255) {
    throw new Error(`NUM_CATEGORIES must be integer in [1..255], got: ${NUM_CATEGORIES_RAW}`);
  }

  log(`🎨 Deploying SecretColorVote with numCategories=${numCategories}… (artifact: ${contractId})`);

  // ── 3) Деплой ──────────────────────────────────────────────────────
  const d = await deploy("SecretColorVote", {
    from: deployer,
    contract: contractId,
    args: [numCategories], // constructor(uint8)
    log: true,
    waitConfirmations,
  });

  // ── 4) Быстрые проверки живости ────────────────────────────────────
  try {
    const ver: string = await read("SecretColorVote", "version");
    const cats: number = await read("SecretColorVote", "categoriesCount");
    const open: boolean = await read("SecretColorVote", "votingOpen");
    log(`✅ Deployed at ${d.address} on ${network.name} (version: ${ver}, categories: ${cats}, votingOpen: ${open})`);
  } catch {
    log(`✅ Deployed at ${d.address} on ${network.name}`);
  }

  // ── 5) Опциональные шаги через ENV ─────────────────────────────────
  // CLOSE=1|true — закрыть голосование
  // PUBLISH=1|true — опубликовать гистограмму (доступно только после закрытия)
  const CLOSE = (process.env.CLOSE ?? "").toLowerCase();
  const PUBLISH = (process.env.PUBLISH ?? "").toLowerCase();
  const doClose = CLOSE === "1" || CLOSE === "true";
  const doPublish = PUBLISH === "1" || PUBLISH === "true";

  if (doClose) {
    const isOpen: boolean = await read("SecretColorVote", "votingOpen");
    if (isOpen) {
      log("🔒 Closing voting…");
      await execute("SecretColorVote", { from: deployer, log: true }, "closeVoting");
      log("🔒 Voting closed");
    } else {
      log("ℹ️ Voting already closed");
    }
  }

  if (doPublish) {
    const isOpen: boolean = await read("SecretColorVote", "votingOpen");
    if (isOpen) {
      log("⚠️ Cannot publish: voting is still open. Set CLOSE=1 first.");
    } else {
      const published: boolean = await read("SecretColorVote", "histogramPublished");
      if (published) {
        log("ℹ️ Histogram already published");
      } else {
        log("📢 Publishing histogram (makePublic)…");
        await execute("SecretColorVote", { from: deployer, log: true }, "publishHistogram");
        log("📢 Histogram published (handles are now publicly decryptable)");
      }
    }
  }

  console.log(`SecretColorVote contract: ${d.address}`);
};

export default func;
func.id = "deploy_secret_color_vote"; // чтобы hardhat-deploy не выполнял повторно
func.tags = ["SecretColorVote"];
