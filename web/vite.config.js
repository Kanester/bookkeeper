import { defineConfig } from 'vite';
import sass from 'sass-embedded';

export default defineConfig({
	base: '',
	css: {
		preprocessorOptions: {
			scss: {
				implementation: sass,
			},
		},
	},
});
