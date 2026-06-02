##
source("renv/activate.R")
renv_activate <- file.path(getwd(), "renv", "activate.R")
if (file.exists(renv_activate)) {
  source(renv_activate)
} else {
  message("[INFO] renv/activate.R not found; skipping activation for now.")
}

.local_init_app_logger <- function(
    log_dir = Sys.getenv("APP_LOG_DIR", unset=paste0(getwd(), "/log/app")),
    app_name = Sys.getenv("APP_NAME", unset="rstudio-app"),
    app_version = Sys.getenv("APP_VERSION", unset="1.0.0"),
    log_level = Sys.getenv("APP_LOG_LEVEL", unset="info"),
    cid = Sys.getenv("HOSTNAME", Sys.info()[["nodename"]]),
    #    audit_log_dir = Sys.getenv("APP_AUDIT_LOG_DIR", unset="/var/log/audit-r")
    audit_log_dir = Sys.getenv("APP_AUDIT_LOG_DIR", unset=file.path("/var/log/audit-r", cid))
) {
  if (!requireNamespace("lgr", quietly=TRUE)) return(invisible(FALSE))
  if (!requireNamespace("jsonlite", quietly=TRUE)) return(invisible(FALSE))
  if (!requireNamespace("uuid", quietly=TRUE)) return(invisible(FALSE))
  if (!requireNamespace("digest", quietly=TRUE)) return(invisible(FALSE))
  
  suppressPackageStartupMessages({
    library(lgr); library(jsonlite); library(uuid); library(digest)
  })

  detect_entry_script <- function() {
    ca <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", ca, value = TRUE)
    if (length(file_arg) == 1) {
      return(normalizePath(sub("^--file=", "", file_arg), winslash = "/", mustWork = FALSE))
    }
    NA_character_
  }
  
  options(keep.source = TRUE)
  options(keep.source.pkgs = TRUE)

  caller_info <- function() {
    ## srcref が取れればそれを使う（取れないことも多い）
    calls <- sys.calls()
    for (i in rev(seq_along(calls))) {
      cl <- calls[[i]]
      sr <- attr(cl, "srcref")
      if (!is.null(sr)) {
        file <- tryCatch(attr(sr, "srcfile")$filename, error = function(e) NA_character_)
        line <- tryCatch(sr[[1]], error = function(e) NA_integer_)
        if (is.character(file) && length(file) == 1 && nzchar(file)) {
          return(list(
            file = normalizePath(file, winslash="/", mustWork=FALSE),
            line = as.integer(line)
          ))
        }
      }
    }
    
    ## フォールバック：少なくとも entry（foo.R）は確実に取れる
    list(file = detect_entry_script(), line = NA_integer_)
  } 
  
  sessid <- paste0("sess-", Sys.getpid(), "-", format(Sys.time(), "%Y%m%d%H%M%S"))
  current_user <- Sys.info()[["user"]]
  dir.create(log_dir, showWarnings=FALSE, recursive=TRUE)
  dir.create(audit_log_dir, showWarnings=FALSE, recursive=TRUE)
  app_log_file_name <- paste(current_user, "app.log", sep="_")
  app_log_file <- file.path(log_dir, app_log_file_name) # 人間可読
  #app_log_file <- file.path(log_dir, "app.log") # 人間可読
  #audit_json_file <- file.path(log_dir, "audit.jsonl") # 1行1JSON
  #audit_json_file <- file.path(audit_log_dir, paste0("audit-", cid,".jsonl"))
  audit_json_file <- file.path(audit_log_dir, "audit.jsonl")
  
  .container_info <- list(
    ecs_cluster = Sys.getenv("ECS_CLUSTER", NA),
    ecs_service = Sys.getenv("ECS_SERVICE", NA),
    ecs_task_family = Sys.getenv("ECS_TASK_FAMILY", NA),
    ecs_task_rev = Sys.getenv("ECS_TASK_REVISION", NA),
    ecs_task_arn = Sys.getenv("ECS_TASK_ARN", NA),
    ecs_container = Sys.getenv("ECS_CONTAINER_NAME", NA),
    container_id = Sys.getenv("HOSTNAME", Sys.info()[["nodename"]])
  )
  
  act_runner = Sys.getenv("ACT_RUNNER", current_user)

  #JSONL rotating function
  .rotate_if_needed <- function(path, max_bytes, max_backups) {
    if (!is.numeric(max_bytes) || is.na(max_bytes) || max_bytes <= 0) return(invisible(FALSE))
    if (!file.exists(path)) return(invisible(FALSE))
    
    sz <- tryCatch(file.info(path)$size, error = function(e) NA_real_)
    if (is.na(sz) || sz < max_bytes) return(invisible(FALSE))
    
    max_backups <- suppressWarnings(as.integer(max_backups))
    if (is.na(max_backups) || max_backups < 1) {
      file.rename(path, paste0(path, ".", format(Sys.time(), "%Y%m%d%H%M%S")))
      return(invisible(TRUE))
    }
    
    oldest <- paste0(path, ".", max_backups)
    if (file.exists(oldest)) unlink(oldest)
    
    if (max_backups >= 2) {
      for (i in rev(seq_len(max_backups - 1))) {
        src <- paste0(path, ".", i)
        dst <- paste0(path, ".", i + 1)
        if (file.exists(src)) file.rename(src, dst)
      }
    }
    
    file.rename(path, paste0(path, ".1"))
    invisible(TRUE)
  }

  # Rotation parameter: 10MB limit and 15 generations
  #max_bytes_audit   <- suppressWarnings(as.numeric(Sys.getenv("APP_AUDIT_MAX_BYTES", "20480")))
  max_bytes_audit   <- suppressWarnings(as.numeric(Sys.getenv("APP_AUDIT_MAX_BYTES", "10485760")))
  max_backups_audit <- suppressWarnings(as.integer(Sys.getenv("APP_AUDIT_MAX_BACKUPS", "15")))
    
  # Appender for console
  appender_console <- AppenderConsole$new(
    layout = LayoutFormat$new(fmt = "%L [%t] %m %f", timestamp_fmt = "%Y-%m-%d %H:%M:%OS3", colors = NULL)
  )
  
  # Appender for log file
  appender_file <- AppenderFile$new(
    file = app_log_file,
    layout = LayoutFormat$new(fmt = "%L [%t] %m %f", timestamp_fmt = "%Y-%m-%d %H:%M:%OS3")
  )
  
  # Appender for JSONL to treat as audit trail 
  AppenderJsonFile <- R6::R6Class("AppenderJsonFile",
                                  inherit = AppenderFile,
                                  #inherit = lgr::Appender,
                                  portable = TRUE,
                                  cloneable = FALSE,
                                  public = list(
                                    append = function(event) {
                                      #JSONL rotation invocation
                                      .rotate_if_needed(self$file, max_bytes_audit, max_backups_audit)
                                      payload <- list(
                                        event_id = uuid::UUIDgenerate(),
                                        ts = format(event$timestamp, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
                                        host = Sys.info()[["nodename"]],
                                        session = sessid,
                                        app_name = app_name,
                                        app_version = app_version,
                                        #level = event$levelname,
                                        level = event$level_name,
                                        message = if (!is.null(event$msg)) event$msg else "",
                                        entry_script = if (!is.null(event$values$entry_script)) event$values$entry_script else NA_character_,
                                        caller = list(
                                          file = if (!is.null(event$values$caller_file)) event$values$caller_file else NA_character_,
                                          line = if (!is.null(event$values$caller_line)) event$values$caller_line else NA_integer_
                                        ),
                                        user = current_user,
#                                        act_user = get0("actual_executor", ifnotfound = current_user),
#                                        act_user = get0("actual_executor", ifnotfound = NA_character_),
                                        act_user = act_runner,
                                        fields = event$values,
                                        ecs = .container_info
                                      )
                                      cat(jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", na = "null"), "\n",
                                          file = self$file, append = TRUE)
                                    }
                                  )
  )
  appender_json <- AppenderJsonFile$new(file = audit_json_file)
  
  # Initialize logger
  logger <- lgr::get_logger("app")
  logger$set_appenders(list(appender_console, appender_file, appender_json))
  logger$set_threshold(log_level)
  
  # Helpers by each log level
  base_env <- .GlobalEnv
  assign("log_info", function(msg, ...) {
    ci  <- caller_info()
    lgr::get_logger("app")$info(
      msg,
      entry_script = detect_entry_script(),
      caller_file = ci$file,
      caller_line = as.integer(ci$line),
      ...
    )
  }, envir = base_env)
  
  assign("log_warn", function(msg, ...) {
    ci  <- caller_info()
    lgr::get_logger("app")$warn(
      msg,
      entry_script = detect_entry_script(),
      caller_file = ci$file,
      caller_line = as.integer(ci$line),
      ...
    )
  }, envir = base_env)
  
  assign("log_error", function(msg, ...) {
    ci  <- caller_info()
    lgr::get_logger("app")$error(
      msg,
      entry_script = detect_entry_script(),
      caller_file = ci$file,
      caller_line = as.integer(ci$line),
      ...
    )
  }, envir = base_env)
  
  assign("log_debug", function(msg, ...) {
    ci  <- caller_info()
    lgr::get_logger("app")$debug(
      msg,
      entry_script = detect_entry_script(),
      caller_file = ci$file,
      caller_line = as.integer(ci$line),
      ...
    )
  }, envir = base_env)
  
  assign("log_set_level", function(level="info") lgr::get_logger("app")$set_threshold(level), envir = base_env)
  
  # Helpers for user_id and session
  assign("current_user_id", function() Sys.getenv("APP_USER_ID", unset = Sys.getenv("USER", unset="unknown")), envir = base_env)
  assign("current_session_id", function() paste0("sess-", Sys.getpid(), "-", format(Sys.time(), "%Y%m%d%H%M%S")), envir = base_env)
  
  # Helpers for arguments
  assign("script_args_pos", function() {
    # trailingOnly=TRUE で、スクリプト名以降の生の位置引数をベクタで返す
    commandArgs(trailingOnly = TRUE)
  }, envir = base_env)
  
  # Helpers for hash
  assign("hash_file", function(path, algo="sha256") {
    if (!is.character(path) || length(path) != 1 || !nzchar(path)) return(NA_character_)
    if (!file.exists(path)) return(NA_character_)
    digest::digest(file = path, algo = algo)
  }, envir = base_env)
  
  assign("hash_object", function(obj, algo="sha256") {
    # RDSシリアライズで安定化させてからハッシュ
    tf <- tempfile(fileext = ".rds")
    on.exit(unlink(tf), add = TRUE)
    saveRDS(obj, tf, version = 2)
    digest::digest(file = tf, algo = algo)
  }, envir = base_env)
  
  assign(".app_logger_initialized", TRUE, envir = base_env)
  invisible(TRUE)
}

try(.local_init_app_logger(), silent = TRUE)
