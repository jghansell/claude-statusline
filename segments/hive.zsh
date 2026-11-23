# Role icon and launch autonomy for sessions launched by Hive.
#
# Emits the icon and autonomy facts, which the core adds to the session segment.

case $HIVE_ROLE in
  *orchestrator*) emit fact icon $I_ORCH ;;
  worker) emit fact icon $I_WORKER ;;
esac
[[ -z $HIVE_AUTONOMY ]] || emit fact autonomy $HIVE_AUTONOMY
