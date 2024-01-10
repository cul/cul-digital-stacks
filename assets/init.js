document.addEventListener("DOMContentLoaded", function() {
    const initManifest = document.getElementById('root').dataset.manifest;
    new ArchivalIIIFViewer({
        id: 'root',
	language: 'en',
        manifest: initManifest
    });
});
