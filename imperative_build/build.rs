use std::env;
use std::fs;
use std::process::Command;
use std::process::exit;
use std::time::UNIX_EPOCH;

fn do_rebuild_build_system(src_path: &str, build_path: &str) -> Result<(), String> {
    let backup_name = format!("{}.old", src_path);
    fs::copy(build_path, &backup_name).unwrap();

    cmd(&["rustc", src_path, "-o", build_path])?;

    fs::remove_file(backup_name).unwrap();

    Ok(())
}

fn get_build_name() -> Result<String, String> {
    Ok(env::current_exe().unwrap()
        .file_name().ok_or("No filename")?
        .to_str().ok_or("Filename cannot be converted to string")?
        .to_owned())
}

fn get_mod_date(path: &str) -> u64 {
    fs::metadata(path)
    .unwrap()
    .modified()
    .unwrap()
    .duration_since(UNIX_EPOCH)
    .unwrap()
    .as_secs()
}

fn cmd(args: &[&str]) -> Result<(), String> {
    let cmd_name = args[0];
    let status = Command::new(cmd_name)
        .stdout(std::process::Stdio::inherit())
        .stderr(std::process::Stdio::inherit())
        .args(&args[1..])
        .status();

    let Ok(status) = status else {
        return Err("Couldn't run command".into())
    };
    if !status.success() {
        return Err("Command failed".into())
    }
    Ok(())
}

fn rebuild_build_system() {
    let binary_name = get_build_name().unwrap();
    let src_name = format!("{}.rs", binary_name);

    let binary_modified = get_mod_date(&binary_name);
    let src_modified = get_mod_date(&src_name);

    if binary_modified <= src_modified {
        println!("Rebuilding build system");
        do_rebuild_build_system(&src_name, &binary_name)
            .expect("failed to rebuild build system");

        println!("Running new version");
        cmd(&["./build"])
            .expect("failed to run new version");
        exit(0);
    }
}

fn main() {
    rebuild_build_system();

    println!("Building main.odin");
    cmd(&["../odin/odin", "build", "test"])
        .expect("failed to build main program");
}
