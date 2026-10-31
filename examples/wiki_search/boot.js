// Run before first paint: mobile reading must not briefly show the desktop
// sidebar while the deferred search module loads. With JS disabled this never
// runs, so the native overview link and no-script explanation remain visible.
document.documentElement.classList.add('js');
