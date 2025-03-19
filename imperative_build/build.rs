use std::env;
use std::fs;
use std::process::Command;
use std::process::exit;
use std::time::UNIX_EPOCH;
use std::time::SystemTimeError;

fn main() {
    rebuild_build_system()
        .expect("failed to build build system");

    println!("Building main.odin");
    cmd(&["../odin/odin", "build", "test"])
        .expect("failed to build main program");
}

#[derive(Debug)]
enum BuildError {
    Io,
    CommandStart,
    CommandFailed,
    InvalidExecutable,
    NonUtf8Filename,
    BackupOperation ,
    TimeConversion,
}

impl From<SystemTimeError> for BuildError {
    fn from(_: SystemTimeError) -> Self {
        BuildError::TimeConversion
    }
}

fn do_rebuild_build_system(src_path: &str, build_path: &str) -> Result<(), BuildError> {
    let backup_name = format!("{}.old", src_path);
    fs::copy(build_path, &backup_name)
        .map_err(|_| BuildError::BackupOperation)?;

    cmd(&["rustc", src_path, "-o", build_path])?;

    fs::remove_file(backup_name)
        .map_err(|_| BuildError::BackupOperation)?;

    Ok(())
}

fn get_build_name() -> Result<String, BuildError> {
    let exe_path = env::current_exe()
        .map_err(|_| BuildError::Io)?;

    let file_name = exe_path.file_name()
        .ok_or(BuildError::InvalidExecutable)?;

    file_name.to_str()
        .ok_or(BuildError::NonUtf8Filename)
        .map(|s| s.to_owned())
}

fn get_mod_date(path: &str) -> Result<u64, BuildError> {
    let metadata = fs::metadata(path)
        .map_err(|_| BuildError::Io)?;

    let modified = metadata.modified()
        .map_err(|_| BuildError::Io)?;

    Ok(modified.duration_since(UNIX_EPOCH)?.as_secs())
}

fn cmd(args: &[&str]) -> Result<(), BuildError> {
    let command_name = args[0];
    let mut command = Command::new(command_name);
    command.args(&args[1..])
        .stdout(std::process::Stdio::inherit())
        .stderr(std::process::Stdio::inherit());

    let status = command.status()
        .map_err(|_| BuildError::CommandStart)?;

    if !status.success() {
        return Err(BuildError::CommandFailed);
    }

    Ok(())
}

fn rebuild_build_system() -> Result<(), BuildError> {
    let binary_name = get_build_name()?;
    let src_name = format!("{}.rs", binary_name);

    let binary_modified = get_mod_date(&binary_name)?;
    let src_modified = get_mod_date(&src_name)?;

    if binary_modified <= src_modified {
        println!("Rebuilding build system");
        do_rebuild_build_system(&src_name, &binary_name)
            .expect("failed to rebuild build system");

        println!("Running new version");
        cmd(&["./build"])
            .expect("failed to run new version");
        exit(0);
    }
    Ok(())
}
