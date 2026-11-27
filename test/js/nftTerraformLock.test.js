const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const yaml = require("js-yaml");

const script = path.resolve(__dirname, "../../scripts/apply-nft-with-lock.sh");
let dir;

beforeEach(() => {
  dir = fs.mkdtempSync(path.join(os.tmpdir(), "nft-lock-test-"));
  fs.writeFileSync(path.join(dir, "aws"), `#!/bin/sh
echo "$*" >> "$CALLS"
if [ "$1" = sts ]; then echo "\${MOCK_ACCOUNT:-448120078528}"; fi
if [ "$2" = put-item ] && [ "\${MOCK_LOCK_HELD:-0}" = 1 ]; then exit 1; fi
`, { mode: 0o755 });
  fs.writeFileSync(path.join(dir, "terraform"), `#!/bin/sh
echo "terraform $*" >> "$CALLS"
exit "\${MOCK_TERRAFORM_EXIT:-0}"
`, { mode: 0o755 });
  fs.writeFileSync(path.join(dir, "uuidgen"), "#!/bin/sh\necho test-owner\n", { mode: 0o755 });
});

afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

function run(extra = {}, args = []) {
  const calls = path.join(dir, "calls");
  const result = spawnSync("bash", [script, ...args], {
    encoding: "utf8",
    env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, CALLS: calls, ...extra },
  });
  return { result, calls: fs.existsSync(calls) ? fs.readFileSync(calls, "utf8") : "" };
}

test("holds the NFT lock for the Terraform apply and conditionally releases it", () => {
  const { result, calls } = run();
  expect(result.status).toBe(0);
  expect(calls.indexOf("dynamodb put-item")).toBeLessThan(calls.indexOf("terraform "));
  expect(calls.indexOf("terraform ")).toBeLessThan(calls.indexOf("dynamodb delete-item"));
  expect(calls).toContain("attribute_not_exists(LockID)");
  expect(calls).toContain("#owner = :owner");
});

test("retains the lock when Terraform fails", () => {
  const { result, calls } = run({ MOCK_TERRAFORM_EXIT: "1" });
  expect(result.status).not.toBe(0);
  expect(calls).toContain("dynamodb put-item");
  expect(calls).not.toContain("dynamodb delete-item");
});

test("refuses credentials for another account before acquiring a lock", () => {
  const { result, calls } = run({ MOCK_ACCOUNT: "123456789012" });
  expect(result.status).not.toBe(0);
  expect(calls).not.toContain("dynamodb put-item");
});

test("does not apply or release another owner's lock", () => {
  const { result, calls } = run({ MOCK_LOCK_HELD: "1" });
  expect(result.status).not.toBe(0);
  expect(calls).not.toContain("terraform ");
  expect(calls).not.toContain("dynamodb delete-item");
});

test("uses the separate NFT task-definition root when requested", () => {
  const { result, calls } = run({}, ["--task-definitions"]);
  expect(result.status).toBe(0);
  expect(calls).toContain("/terraform/nft/ecs_task_definition apply");
});

test.each([
  [".github/workflows/apply.yml", "apply", "Terraform apply"],
  [".github/workflows/update-task-definition.yml", "apply", "Terraform apply"],
  [".github/workflows/refresh-task-definitions.yml", "refresh-one-login-simulator", "Refresh One Login simulator service"],
])("%s holds the shared lock around NFT mutation", (file, job, operation) => {
  const workflow = yaml.load(fs.readFileSync(path.resolve(__dirname, "../..", file), "utf8"));
  const steps = workflow.jobs[job].steps;
  const acquire = steps.findIndex(step => step.name === "Acquire shared NFT infrastructure lock");
  const mutation = steps.findIndex(step => step.name === operation);
  const release = steps.findIndex(step => step.name === "Release shared NFT infrastructure lock");
  expect(acquire).toBeGreaterThanOrEqual(0);
  expect(acquire).toBeLessThan(mutation);
  expect(mutation).toBeLessThan(release);
  expect(steps[acquire].run).toContain("attribute_not_exists(LockID)");
  expect(steps[release].run).toContain("#owner = :owner");
  expect(steps[release].if).toContain("outcome == 'success'");
});
