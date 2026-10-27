///|
/// Node adapter for the supported filesystem CLI. No direct-write fallback.
#external
priv type StageResult

///|
#external
priv type FileStat

///|
#module("node:fs")
extern "js" fn make_temp(prefix : String) -> String = "mkdtempSync"

///|
#module("node:fs")
extern "js" fn open_temp(path : String, flags : String) -> Int = "openSync"

///|
#module("node:fs")
extern "js" fn write_temp(fd : Int, bytes : Bytes) -> Unit = "writeFileSync"

///|
#module("node:fs")
extern "js" fn close_temp(fd : Int) -> Unit = "closeSync"

///|
#module("node:fs")
extern "js" fn stat_target(path : String) -> FileStat = "lstatSync"

///|
#module("node:fs")
extern "js" fn mode_temp(path : String, mode : Int) -> Unit = "chmodSync"

///|
#module("node:fs")
extern "js" fn rename_temp(source : String, target : String) -> Unit = "renameSync"

///|
#module("node:fs")
extern "js" fn unlink_temp(path : String) -> Unit = "unlinkSync"

///|
#module("node:fs")
extern "js" fn remove_temp_dir(path : String) -> Unit = "rmdirSync"

///|
#module("node:path")
extern "js" fn parent_path(path : String) -> String = "dirname"

///|
extern "js" fn StageResult::ok(self : StageResult) -> Bool = "r => r.ok"

///|
extern "js" fn StageResult::value(self : StageResult) -> String = "r => r.value"

///|
extern "js" fn stage_ffi(
  mkdtemp : (String) -> String,
  open : (String, String) -> Int,
  write : (Int, Bytes) -> Unit,
  close : (Int) -> Unit,
  stat : (String) -> FileStat,
  chmod : (String, Int) -> Unit,
  unlink : (String) -> Unit,
  rmdir : (String) -> Unit,
  dirname : (String) -> String,
  target : String,
  bytes : Bytes,
) -> StageResult =
  #| (mkdtemp, open, write, close, stat, chmod, unlink, rmdir, dirname, target, bytes) => {
  #|   let dir, file, fd, owned = false;
  #|   try {
  #|     let mode;
  #|     try {
  #|       const info = stat(target);
  #|       if (!info.isFile()) throw new Error('destination is not a regular file: ' + target);
  #|       mode = info.mode & 0o777;
  #|     } catch (error) { if (error.code !== 'ENOENT') throw error; }
  #|     dir = mkdtemp(dirname(target) + '/.lattice-stage-');
  #|     file = dir + '/payload';
  #|     fd = open(file, 'wx');
  #|     owned = true;
  #|     write(fd, bytes);
  #|     const closing = fd; fd = undefined; close(closing);
  #|     if (mode !== undefined) chmod(file, mode);
  #|     return { ok: true, value: file };
  #|   } catch (error) {
  #|     let message = String(error);
  #|     if (fd !== undefined) { try { close(fd); } catch (e) { message += '; close: ' + e; } }
  #|     if (owned) { try { unlink(file); } catch (e) { message += '; retained stage ' + file + ': ' + e; } }
  #|     if (dir) { try { rmdir(dir); } catch (e) { message += '; retained stage directory ' + dir + ': ' + e; } }
  #|     return { ok: false, value: message };
  #|   }
  #| }

///|
fn staged_publication_supported() -> Bool {
  true
}

///|
fn stage_output(path : String, bytes : Bytes) -> String raise @fs.IOError {
  let result = stage_ffi(
    make_temp, open_temp, write_temp, close_temp, stat_target, mode_temp, unlink_temp,
    remove_temp_dir, parent_path, path, bytes,
  )
  if !result.ok() {
    raise @fs.IOError(result.value())
  }
  result.value()
}

///|
extern "js" fn replace_ffi(
  rename : (String, String) -> Unit,
  stat : (String) -> FileStat,
  staged : String,
  target : String,
) -> String =
  #| (rename, stat, staged, target) => {
  #|   try {
  #|     try {
  #|       if (!stat(target).isFile()) throw new Error('destination is not a regular file: ' + target);
  #|     } catch (error) { if (error.code !== 'ENOENT') throw error; }
  #|     rename(staged, target);
  #|     return '';
  #|   } catch (error) { return String(error); }
  #| }

///|
fn replace_output(staged : String, target : String) -> Unit raise @fs.IOError {
  let error = replace_ffi(rename_temp, stat_target, staged, target)
  if error != "" {
    raise @fs.IOError(error)
  }
}

///|
extern "js" fn discard_ffi(
  unlink : (String) -> Unit,
  rmdir : (String) -> Unit,
  dirname : (String) -> String,
  staged : String,
) -> String =
  #| (unlink, rmdir, dirname, staged) => {
  #|   try {
  #|     try { unlink(staged); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  #|     rmdir(dirname(staged));
  #|     return '';
  #|   } catch (error) { return 'retained stage ' + staged + ': ' + error; }
  #| }

///|
fn discard_output(staged : String) -> String {
  discard_ffi(unlink_temp, remove_temp_dir, parent_path, staged)
}
