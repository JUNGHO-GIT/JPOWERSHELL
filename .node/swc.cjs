// swc.cjs

const { spawn } = require(`child_process`);
const fs = require(`fs`);
const path = require(`path`);
const process = require(`process`);
const { logger, runCommand } = require(`./utils.cjs`);

// 인자 파싱 ------------------------------------------------------------------------------------
const argv = process.argv.slice(2);
const args1 = argv.find(arg => [`--npm`, `--pnpm`, `--yarn`, `--bun`].includes(arg))?.replace(`--`, ``) || ``;
const args2 = argv.find(arg => [`--compile`, `--watch`].includes(arg))?.replace(`--`, ``) || ``;

// 컴파일 실행 ----------------------------------------------------------------------------------
const compile = () => {
	logger(`info`, `컴파일 시작`);
	const outDir = path.join(process.cwd(), `out`);

	fs.existsSync(outDir) && fs.rmSync(outDir, { recursive: true, force: true });
	logger(`info`, `기존 out 디렉토리 삭제 완료`);

	args1 === `npm` ? (
		runCommand(args1, [`exec`, `--`, `swc`, `src`, `-d`, `out`, `--strip-leading-paths`]),
		runCommand(args1, [`exec`, `--`, `tsc-alias`, `-p`, `tsconfig.json`, `-f`])
	) : args1 === `pnpm` ? (
		runCommand(args1, [`swc`, `src`, `-d`, `out`, `--strip-leading-paths`]),
		runCommand(args1, [`tsc-alias`, `-p`, `tsconfig.json`, `-f`])
	) : args1 === `yarn` ? (
		runCommand(args1, [`swc`, `src`, `-d`, `out`, `--strip-leading-paths`]),
		runCommand(args1, [`tsc-alias`, `-p`, `tsconfig.json`, `-f`])
	) : args1 === `bun` ? (
		runCommand(args1, [`swc`, `src`, `-d`, `out`, `--strip-leading-paths`]),
		runCommand(args1, [`tsc-alias`, `-p`, `tsconfig.json`, `-f`])
	) : (
		(() => {
			throw new Error(`알 수 없는 패키지 매니저: ${args1}`);
		})()
	);

	logger(`success`, `컴파일 완료`);
};

// 워치 모드 ----------------------------------------------------------------------------------
const watch = () => {
	logger(`info`, `워치 모드 시작`);

	const swcArgs = args1 === `npm` ? (
		[`exec`, `--`, `swc`, `src`, `-d`, `out`, `--strip-leading-paths`, `--watch`]
	) : args1 === `pnpm` ? (
		[`swc`, `src`, `-d`, `out`, `--strip-leading-paths`, `--watch`]
	) : args1 === `yarn` ? (
		[`swc`, `src`, `-d`, `out`, `--strip-leading-paths`, `--watch`]
	) : args1 === `bun` ? (
		[`swc`, `src`, `-d`, `out`, `--strip-leading-paths`, `--watch`]
	) : (
		[]
	);

	const aliasArgs = args1 === `npm` ? (
		[`exec`, `--`, `tsc-alias`, `-p`, `tsconfig.json`, `-f`, `--watch`]
	) : args1 === `pnpm` ? (
		[`tsc-alias`, `-p`, `tsconfig.json`, `-f`, `--watch`]
	) : args1 === `yarn` ? (
		[`tsc-alias`, `-p`, `tsconfig.json`, `-f`, `--watch`]
	) : args1 === `bun` ? (
		[`tsc-alias`, `-p`, `tsconfig.json`, `-f`, `--watch`]
	) : (
		[]
	);

	const swcProc = spawn(args1, swcArgs, {
		stdio: `inherit`,
		shell: true,
		env: process.env
	});

	const aliasProc = spawn(args1, aliasArgs, {
		stdio: `inherit`,
		shell: true,
		env: process.env
	});

	const cleanup = () => {
		logger(`info`, `워치 모드 종료 중...`);
		swcProc.kill();
		aliasProc.kill();
		process.exit(0);
	};

	process.on(`SIGINT`, cleanup);
	process.on(`SIGTERM`, cleanup);

	swcProc.on(`close`, (code) => {
		code !== 0 && logger(`warn`, `swc 종료 (exit code: ${code})`);
	});

	aliasProc.on(`close`, (code) => {
		code !== 0 && logger(`warn`, `tsc-alias 종료 (exit code: ${code})`);
	});

	logger(`success`, `워치 모드 실행 중`);
};

// 실행 ---------------------------------------------------------------------------------------
(() => {
	logger(`info`, `스크립트 실행: swc.cjs (인자: ${argv.join(` `) || `none`})`);

	try {
		args2 === `compile` ? compile() :
		args2 === `watch` ? watch() : (() => {
			throw new Error(`Invalid argument. Use --compile or --watch.`);
		})();
	}
	catch (e) {
		const msg = e instanceof Error ? e.message : String(e);
		logger(`error`, `스크립트 실행 실패: ${msg}`);
		process.exit(1);
	}
})();