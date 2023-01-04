importScripts('pdfgrep_pipeline.js');

self.pipeline = null

onmessage = async ({ data: { files, query, pdfgrep_wasm, pdfgrep_js } }) => {
    if (pdfgrep_wasm && pdfgrep_js) {
        try {
            self.pipeline = new PDFPipeline(pdfgrep_wasm, pdfgrep_js, msg=>postMessage({print: msg}), PDFPipeline.ScriptLoaderWorker);
        } catch (err) {
            postMessage({exception: 'Exception during initialization: ' + err.toString() + '\nStack:\n' + err.stack});
        }
    }
    else if (files && query && self.pipeline) {
        try
        {
            postMessage(await self.pipeline.search(files, query));
        }
        catch(err)
        {
            postMessage({exception: 'Exception during compilation: ' + err.toString() + '\nStack:\n' + err.stack});
        }
    }
}