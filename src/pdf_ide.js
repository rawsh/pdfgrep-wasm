function upload_pdf() {
    let files = document.getElementById('pdfinput').files;
    if (files.length == 0) {
        return;
    }
    Module.setStatus('Uploading...');
    Array.from(files).forEach(file => {
        let reader = new FileReader();
        reader.addEventListener('loadend', () => {
            let data = reader.result;
            const pdf_data = new Uint8Array(data);

            // upload to emscripten memfs
            // write to tmp
            FS.writeFile('/tmp/' + file.name, pdf_data);
            console.log("wrote " + file.name + " to memfs");
        });
        reader.readAsArrayBuffer(file);
    });
    Module.setStatus('');
}

function search_uploads() {
    let query = document.getElementById('pdfsearch').value;
    document.getElementById("output").value = "";

    // list all files in memfs, excluding . and ..
    let files = FS.readdir('/tmp').filter(file => file != '.' && file != '..');

    // https://github.com/emscripten-core/emscripten/issues/12219#issuecomment-714186373
    // clear memory after calling main
    this.memory_header_size = 2 ** 25;
    console.assert(this.memory_header_size % 4 == 0);
    console.assert(Module.HEAP32.slice(this.memory_header_size / 4).every(x => x == 0)); // is there a faster way to check that it's all zeros above a certain pointer?
    const header = Uint8Array.from(Module.HEAPU8.slice(0, this.memory_header_size));
    
    // search for query in memfs
    // NOCLEANUP_callMain(["-iHn", query, ...files]);
    // let args = getArgs(["-iHn", query, ...files]);
    FS.chdir('/tmp');
    callMain(["-iHn", query, ...files]);

    // restore memory
    HEAPU8.fill(0);
    HEAPU8.set(header);
}
