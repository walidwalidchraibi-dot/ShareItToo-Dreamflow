import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const messages = readFileSync(
  new URL('../../lib/screens/messages_screen.dart', import.meta.url),
  'utf8',
);

test('messages list cannot regain superseded demo and presentation helpers', () => {
  for (const removedSymbol of [
    '_buildDemoMessageState',
    '_tabCounts',
    '_presenceText',
    '_uspLine',
  ]) {
    assert.doesNotMatch(messages, new RegExp(`\\b${removedSymbol}\\b`));
  }
});

test('message loading and the bounded translation demo stay wired', () => {
  assert.match(messages, /Future<void> _loadData\(\) async/);
  assert.match(messages, /DataService\.getMessageThreadsForUser\(user\.id\)/);
  assert.match(
    messages,
    /DataService\.getArchivedMessageThreadsForUser\(user\.id\)/,
  );
  assert.match(messages, /MessagesSettingsService\.get\(\)/);
  assert.match(messages, /BlockedUsersService\.getBlockedUserIds\(\)/);
  assert.equal(
    (messages.match(/_withTranslationDemoThread\(\s*user: user,/g) || []).length,
    2,
  );
  assert.match(messages, /final demo = _buildTranslationDemoThread\(user\);/);
  assert.match(messages, /thread\.id == _translationDemoThreadId/);
});

test('active filtering and search stay wired', () => {
  assert.match(messages, /final threads = _filteredThreads\(\);/);
  assert.match(messages, /onPressed: _toggleSearch/);
  assert.match(
    messages,
    /_InlineSearchBar\([\s\S]*?onChanged: \(v\) =>\s*setState\(\(\) => _searchQuery = v\.trim\(\)\)/,
  );
  assert.match(
    messages,
    /filtered = filtered\.where\(\(t\) => _matchesQuery\(t, query\)\)\.toList\(\);/,
  );
  assert.match(messages, /case _MessagesFilter\.blocked:\s+return isBlocked;/);
});

test('opening threads and unread state stay wired', () => {
  assert.match(messages, /final hasUnread = _hasUnread\(thread\);/);
  assert.match(
    messages,
    /_ThreadDismissible\([\s\S]*?_ChatThreadTile\([\s\S]*?showPreview:\s*_messageSettings\.showChatPreview,[\s\S]*?onTap: \(\) => _openThread\(thread, other\),[\s\S]*?onLongPress: \(\) =>\s*_openThreadOptions\(thread\)/,
  );
  assert.match(messages, /builder: \(_\) => MessageThreadScreen\(/);
  assert.match(
    messages,
    /return thread\.messages\.any\(\(m\) => m\.senderId != userId && !m\.isRead\);/,
  );
});

test('blocking and archive controls stay wired', () => {
  assert.match(
    messages,
    /onArchiveToggle: \(\) async \{[\s\S]*?final isArchived = thread\s*\.archivedForUserIds\s*\.contains\(_currentUser!\.id\);[\s\S]*?if \(isArchived\) \{[\s\S]*?await DataService\s*\.unarchiveMessageThreadForUser\(\s*threadId: thread\.id,\s*userId: _currentUser!\.id\);[\s\S]*?\} else \{[\s\S]*?await DataService\s*\.archiveMessageThreadForUser\(\s*threadId: thread\.id,\s*userId: _currentUser!\.id\);[\s\S]*?\}[\s\S]*?await _loadData\(\);[\s\S]*?\},\s+onDelete:/,
  );
  assert.match(
    messages,
    /onDelete: \(\) async \{[\s\S]*?final ok = await _confirmDelete\(\);[\s\S]*?if \(!ok\) return;[\s\S]*?await DataService\.deleteMessageThread\(\s*threadId: thread\.id\);[\s\S]*?await _loadData\(\);[\s\S]*?\},\s+child: _ChatThreadTile/,
  );
  assert.match(
    messages,
    /_ThreadOptionsSheet\([\s\S]*?canBlock: _canBlockThread\(thread\)[\s\S]*?isBlocked: _isOtherUserBlocked\(thread\)/,
  );
  assert.match(messages, /case 'block':/);
  assert.match(messages, /BlockedUsersService\.blockUser\(otherUserId\)/);
  assert.match(messages, /BlockedUsersService\.unblockUser\(otherUserId\)/);
});

test('message settings stay reachable from the app bar', () => {
  assert.match(messages, /onPressed: _openMessageSettings/);
  assert.match(
    messages,
    /Future<void> _openMessageSettings\(\) async[\s\S]*?MessagesSettingsScreen\(\)[\s\S]*?await _loadData\(\)/,
  );
});
