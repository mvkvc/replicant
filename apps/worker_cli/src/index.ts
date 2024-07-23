import { Command, Option } from "commander";
import { generateWorkerSalt, startWorker } from "worker_sdk";

const program = new Command();

program
  .addOption(
    new Option("-m, --modelName <model>", "Model name")
      .env("WORKER_MODEL")
      .makeOptionMandatory(),
  )
  .addOption(
    new Option("-k, --workerAPIKey <api_key>", "API key")
      .env("WORKER_API_KEY")
      .makeOptionMandatory(),
  )
  .addOption(
    new Option("-us, --urlServer <url_server>", "URL of the socket server")
      .env("WORKER_URL_SERVER")
      .default("wss://platform.replicantzk.com")
      .makeOptionMandatory(),
  )
  .addOption(
    new Option("-ul, --urlLLM <url_llm>", "URL of the LLM server")
      .env("WORKER_URL_LLM")
      .default("http://localhost:11434")
      .makeOptionMandatory(),
  )
  .addOption(
    new Option("-s, --workerSalt <workerSalt>", "worker ID salt").env(
      "WORKER_SALT",
    ),
  );

program.parse();
const opts = program.opts();
opts.workerSalt = opts.workerSalt || generateWorkerSalt();

function consoleMessageFn(message: string, _status?: "running" | "stopped") {
  console.log(`LOG: ${message}`);
}

const { workerAPIKey, workerSalt, ...displayOpts } = opts;
consoleMessageFn(
  `Starting worker CLI with options: ${JSON.stringify(displayOpts)}`,
);

console.log("LOG: ", opts);

await startWorker(
  consoleMessageFn,
  opts.modelName,
  opts.workerAPIKey,
  opts.workerSalt,
  opts.urlServer,
  opts.urlLLM,
);
