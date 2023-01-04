class PDFPipeline
{
    static preRun = [];
    static calledRun = false;

    static ScriptLoaderWorker(src)
    {
        return Promise.resolve(self.importScripts(src));
    }

    constructor(pdfgrep_wasm, pdfgrep_js, print) {
        this.print = print;
        this.wasm_module_promise = fetch(pdfgrep_wasm).then(WebAssembly.compileStreaming);
        this.em_module_promise = this.script_loader(pdfgrep_js);
        this.Module = this.load_module(pdfgrep_wasm, pdfgrep_js);
    }

    terminate() {
        this.Module = null;
    }

    async load_module() {
        const [em_module, wasm_module] = await Promise.all([this.em_module_promise, WebAssembly.compileStreaming ? this.wasm_module_promise : this.wasm_module_promise.then(r => r.arrayBuffer())]);
        
        const Module = {
            thisProgram: 'pdfgrep',
            preRun: [() => Module.FS.chdir('/tmp')],
            postRun: [],
            output_stdout : '',
            print: (text) => {
                if (arguments.length > 1) text = Array.prototype.slice.call(arguments).join(' ');
                Module.output_stdout += text + '\n';
                this.print(text);
            },
            output_stderr : '',
            printErr: (text) => {
                if (arguments.length > 1) text = Array.prototype.slice.call(arguments).join(' ');
                Module.output_stderr += text + '\n';
                this.print(text);
            },
            callMainWithRedirects: (args) => {
                // https://github.com/emscripten-core/emscripten/issues/12219#issuecomment-714186373
                // clear memory after calling main
                const memory_header_size = 2 ** 25;
                console.assert(memory_header_size % 4 == 0);
                console.assert(Module.HEAP32.slice(memory_header_size / 4).every(x => x == 0)); // is there a faster way to check that it's all zeros above a certain pointer?
                const header = Uint8Array.from(Module.HEAPU8.slice(0, memory_header_size));

                // run main
                Module.output_stdout = '';
                Module.output_stderr = '';
                const exit_code = Module.callMain(args);
                Module._flush_streams();

                // restore memory
                Module.HEAPU8.fill(0);
                Module.HEAPU8.set(header);

                return {
                    exit_code: exit_code,
                    stdout: Module.output_stdout,
                    stderr: Module.output_stderr
                };
            },
        }

        const initialized_module = await pdfgrep(Module);
        return initialized_module;
    }
}