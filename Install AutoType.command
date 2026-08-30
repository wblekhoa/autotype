#!/bin/bash
# Bấm đúp file này trong Finder để cài AutoType.
# Không cần biết Terminal — cửa sổ đen hiện ra là bình thường.
set -u

project_root="$(cd "$(dirname "$0")" && pwd)"
installer="$project_root/install.sh"

printf '\n  AutoType — trình cài đặt\n'
printf '  Thường xong trong khoảng 10 giây.\n'

status=0
if [[ -x "$installer" ]]; then
  "$installer" "$@" || status=$?
else
  printf '\n  Không tìm thấy install.sh cạnh file này.\n' >&2
  printf '  Hãy giải nén toàn bộ thư mục rồi bấm đúp lại.\n' >&2
  status=1
fi

if [[ "$status" -ne 0 ]]; then
  printf '\n  Cài chưa xong. Bạn có thể copy toàn bộ cửa sổ này gửi cho AI để nhờ xem giúp.\n' >&2
fi

if [[ -t 0 ]]; then
  printf '\n  Bấm Enter để đóng cửa sổ này...'
  read -r _x
fi
exit "$status"
