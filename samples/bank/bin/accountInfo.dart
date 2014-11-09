/**
 * Model
 */
class AccountInfo {
  String _id;
  String _accountHolder;
  String _type;
  int _balance;

  String get id => _id;
  set id(String value) => _id = value;
  String get accountHolder => _accountHolder;
  set accountHolder(String value) => _accountHolder = value;
  String get type => _type;
  set type(String value) => _type = value;
  int get balance => _balance;
  set balance(int value) => _balance = value;

  AccountInfo(this._id, this._accountHolder, this._type, this._balance);

  AccountInfo.fromMap(Map m) {
    _id = m['id'];
    _accountHolder = m['accountHolder'];
    _type = m['type'];
    _balance = m['balance'];
  }

  toJson() {
    return {'id':_id, 'accountHolder':_accountHolder, 'type':_type, 'balance':_balance};
  }
}
