#!/bin/bash

nvidia-smi

# Runtime Parameters
MODEL_NAME=""
MODEL_DIR=""

# Default Argument Values
NVIDIA_TF32_OVERRIDE=""

# TODO: remove when real dataloader is implemented
DATA_DIR="/tmp"

BYPASS_ARGUMENTS=""
TF_AUTO_JIT_XLA_FLAG=""

# Loop through arguments and process them
for arg in "$@"
do
    case $arg in
        --model_name=*)
        MODEL_NAME="${arg#*=}"
        shift # Remove --model_name from processing
        ;;
        --no_tf32)
        NVIDIA_TF32_OVERRIDE="NVIDIA_TF32_OVERRIDE=0"
        shift # Remove --no_tf32 from processing
        ;;
        --data_dir=*)
        shift # Remove --data_dir= from processing
        ;;
        --vocab_size=*)
        shift # Remove --vocab_size= from processing
        ;;
        --minimum_segment_size=*)
        shift # Remove --minimum_segment_size= from processing
        ;;
        --input_saved_model_dir=*)
        MODEL_DIR="${arg#*=}"
        shift # Remove --input_saved_model_dir= from processing
        ;;
        --use_xla_auto_jit)
        TF_AUTO_JIT_XLA_FLAG="TF_XLA_FLAGS=--tf_xla_auto_jit=2"
        shift # Remove --use_xla_auto_jit from processing
        ;;
        *)
        BYPASS_ARGUMENTS=" ${BYPASS_ARGUMENTS} ${arg}"
        ;;
    esac
done

# ============== Set model specific parameters ============= #

MIN_SEGMENT_SIZE=5
VOCAB_SIZE=-1

case ${MODEL_NAME} in
  "bert_base_uncased" | "bert_large_uncased")
    VOCAB_SIZE=30522
    ;;

  "bert_base_cased" | "bert_large_cased")
    VOCAB_SIZE=28996
    ;;

  "bart_base" | "bart_large")
    VOCAB_SIZE=50265
    MIN_SEGMENT_SIZE=90
    ;;
esac

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% #

echo -e "\n********************************************************************"
echo "[*] MODEL_NAME: ${MODEL_NAME}"
echo ""
echo "[*] DATA_DIR: ${DATA_DIR}"
echo "[*] MODEL_DIR: ${MODEL_DIR}"
echo ""
echo "[*] NVIDIA_TF32_OVERRIDE: ${NVIDIA_TF32_OVERRIDE}"
echo ""
# Custom Transormers Task Flags
echo "[*] MIN_SEGMENT_SIZE: ${MIN_SEGMENT_SIZE}"
echo "[*] VOCAB_SIZE: ${VOCAB_SIZE}"
echo ""
echo "[*] TF_AUTO_JIT_XLA_FLAG: ${TF_AUTO_JIT_XLA_FLAG}"
echo "[*] BYPASS_ARGUMENTS: $(echo \"${BYPASS_ARGUMENTS}\" | tr -s ' ')"

echo -e "********************************************************************\n"

# ======================= ARGUMENT VALIDATION ======================= #

# Dataset Directory

if [[ -z ${DATA_DIR} ]]; then
    echo "ERROR: \`--data_dir=/path/to/directory\` is missing."
    exit 1
fi

if [[ ! -d ${DATA_DIR} ]]; then
    echo "ERROR: \`--data_dir=/path/to/directory\` does not exist. [Received: \`${DATA_DIR}\`]"
    exit 1
fi

# ----------------------  Model Directory --------------

if [[ -z ${MODEL_DIR} ]]; then
    echo "ERROR: \`--input_saved_model_dir=/path/to/directory\` is missing."
    exit 1
fi

if [[ ! -d ${MODEL_DIR} ]]; then
    echo "ERROR: \`--input_saved_model_dir=/path/to/directory\` does not exist. [Received: \`${MODEL_DIR}\`]"
    exit 1
fi

INPUT_SAVED_MODEL_DIR=${MODEL_DIR}/${MODEL_NAME}/pb_model

if [[ ! -d ${INPUT_SAVED_MODEL_DIR} ]]; then
    echo "ERROR: the directory \`${INPUT_SAVED_MODEL_DIR}\` does not exist."
    exit 1
fi

# %%%%%%%%%%%%%%%%%%%%%%% ARGUMENT VALIDATION %%%%%%%%%%%%%%%%%%%%%%% #

BENCH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
cd ${BENCH_DIR}

# Execute the example

PREPEND_COMMAND="${TF_AUTO_JIT_XLA_FLAG} ${NVIDIA_TF32_OVERRIDE}"

COMMAND="${PREPEND_COMMAND} python transformers.py \
    --input_saved_model_dir ${INPUT_SAVED_MODEL_DIR} \
    --data_dir ${DATA_DIR} \
    --vocab_size ${VOCAB_SIZE} \
    --minimum_segment_size ${MIN_SEGMENT_SIZE} \
    ${BYPASS_ARGUMENTS}"

COMMAND=$(echo "${COMMAND}" | tr -s " ")

echo -e "**Executing:**\n\n${COMMAND}\n"
sleep 5

eval ${COMMAND}
