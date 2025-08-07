import { build } from 'esbuild';
import { sassPlugin } from 'esbuild-sass-plugin';

await build({
	entryPoints: ['src/app.ts'],
	bundle: true,
	minify: true,
	treeShaking: true,
	outfile: 'dist/index.js',
	format: 'esm',
	platform: 'browser',
	target: 'esnext',
	sourcemap: true,
	tsconfig: 'tsconfig.json',
	plugins: [
		sassPlugin({
			type: 'css',
			embedded: true
		})
	]
})
	.then(() => console.log('Esbuild: build success!'))
	.catch(() => process.exit(1));
