/// Port of diff-parser.ts.
class DiffLineType {
  static const context = 'context';
  static const removed = 'removed';
  static const added = 'added';
  static const header = 'header';
}

class DiffLine {
  final String content;
  final String type;
  final int? oldLine;
  final int? newLine;
  DiffLine(this.content, this.type, {this.oldLine, this.newLine});
}

class DiffHunk {
  final String header;
  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final List<DiffLine> lines;
  DiffHunk(this.header, this.oldStart, this.oldCount, this.newStart,
      this.newCount, this.lines);
}

class ParsedDiffFile {
  final String filename;
  final String oldFile;
  final String newFile;
  final List<String> header;
  final List<DiffHunk> hunks;
  ParsedDiffFile(this.filename, this.oldFile, this.newFile, this.header,
      this.hunks);
}

List<ParsedDiffFile> parseDiff(String text) {
  if (text.trim().isEmpty) return [];
  final files = <ParsedDiffFile>[];
  final chunks = text.split(RegExp('^diff --git ', multiLine: true));
  for (final chunk in chunks) {
    if (chunk.trim().isEmpty) continue;
    final header = 'diff --git $chunk';
    final lines = header.split('\n');
    final fm = RegExp(r'^diff --git a/(.+?) b/(.+?)$', multiLine: true)
        .firstMatch(header);
    if (fm == null) continue;
    final file = ParsedDiffFile(
        fm.group(1) ?? '', fm.group(2) ?? '', fm.group(2) ?? '', [], []);
    var inHunk = false;
    DiffHunk? currentHunk;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('diff --git ')) {
        file.header.add(line);
      } else if (line.startsWith('index ') ||
          line.startsWith('--- ') ||
          line.startsWith('+++ ')) {
        file.header.add(line);
      } else if (line.startsWith('@@')) {
        final m = RegExp(r'@@ -(\d+),?(\d*) \+(\d+),?(\d*) @@(.*)')
            .firstMatch(line);
        if (m != null) {
          currentHunk = DiffHunk(
            line,
            int.parse(m.group(1)!),
            m.group(2)!.isNotEmpty ? int.parse(m.group(2)!) : 1,
            int.parse(m.group(3)!),
            m.group(4)!.isNotEmpty ? int.parse(m.group(4)!) : 1,
            [],
          );
          file.hunks.add(currentHunk);
          inHunk = true;
        }
      } else if (inHunk && currentHunk != null) {
        if (line.startsWith('-')) {
          currentHunk.lines.add(DiffLine(
            line.substring(1),
            DiffLineType.removed,
            oldLine: currentHunk.oldStart +
                currentHunk.lines
                    .where((l) => l.type != DiffLineType.added)
                    .length,
          ));
        } else if (line.startsWith('+')) {
          currentHunk.lines.add(DiffLine(
            line.substring(1),
            DiffLineType.added,
            newLine: currentHunk.newStart +
                currentHunk.lines
                    .where((l) => l.type != DiffLineType.removed)
                    .length,
          ));
        } else if (line.startsWith(' ') || line.isEmpty) {
          final content = line.startsWith(' ') ? line.substring(1) : line;
          final oldCnt = currentHunk.lines
              .where((l) => l.type != DiffLineType.added)
              .length;
          final newCnt = currentHunk.lines
              .where((l) => l.type != DiffLineType.removed)
              .length;
          currentHunk.lines.add(DiffLine(
            content,
            DiffLineType.context,
            oldLine: currentHunk.oldStart + oldCnt,
            newLine: currentHunk.newStart + newCnt,
          ));
        } else if (line.startsWith('\\ ')) {
          // "\ No newline at end of file" — skip
        }
      }
    }
    if (file.hunks.isNotEmpty) files.add(file);
  }
  return files;
}