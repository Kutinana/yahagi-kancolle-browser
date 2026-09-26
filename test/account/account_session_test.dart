import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import '../fixtures/kcsapi_fixtures.dart';

void main() {
  test(
    'identity comes from the API and a new login invalidates the old scope',
    () {
      final session = AccountSession();
      addTearDown(session.dispose);
      expect(session.current.isKnown, isFalse);
      session.accept(
        kcsapiEvent('/kcsapi/api_port/port', {
          'api_basic': {'api_member_id': '1001'},
        }),
      );
      final first = session.current;
      expect(first.memberId, 1001);
      expect(first.key('fleet'), 'account.1001.fleet');
      session.accept(
        kcsapiEvent('/kcsapi/api_port/port', {
          'api_basic': {'api_member_id': '1001'},
        }),
      );
      expect(session.isCurrent(first), isTrue);
      session.accept(kcsapiEvent('/kcsapi/api_start2/getData', {}));
      expect(session.current.isKnown, isFalse);
      expect(session.isCurrent(first), isFalse);
      session.accept(
        kcsapiEvent('/kcsapi/api_get_member/basic', {'api_member_id': 1001}),
      );
      expect(session.isCurrent(first), isFalse);
      expect(session.current.key('fleet'), first.key('fleet'));
    },
  );

  test(
    'failed identity responses cannot switch accounts and logout clears identity',
    () {
      final session = AccountSession(initialMemberId: 1001);
      addTearDown(session.dispose);
      final scope = session.current;
      session.accept(
        kcsapiEvent('/kcsapi/api_get_member/basic', {
          'api_member_id': 2002,
        }, apiResult: 0),
      );
      expect(session.isCurrent(scope), isTrue);
      session.reset();
      expect(session.current.isKnown, isFalse);
      expect(session.isCurrent(scope), isFalse);
      expect(() => session.current.key('fleet'), throwsStateError);
    },
  );
}
