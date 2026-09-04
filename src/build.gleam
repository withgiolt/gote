import gleam/io
import glowvm/build

pub fn main() {
  case build.build(output_dir: "dist", module_name: "gote") {
    Ok(_) -> io.println("built gote -> dist/")
    Error(e) -> {
      io.println("build failed: " <> e)
      panic as "glowvm build failed"
    }
  }
}
