/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2015 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;
using zcd;

namespace AppDomain
{
    namespace ModRpc
    {
        public errordomain StubError
        {
            DID_NOT_WAIT_REPLY,
            GENERIC
        }

        public errordomain DeserializeError
        {
            GENERIC
        }

        public interface ISerializable : Object
        {
            public abstract bool check_serialization();
        }

        public interface ITcpClientRootStub : Object
        {
            protected abstract bool hurry_getter();
            protected abstract void hurry_setter(bool new_value);
            public bool hurry {
                get {
                    return hurry_getter();
                }
                set {
                    hurry_setter(value);
                }
            }

            protected abstract bool wait_reply_getter();
            protected abstract void wait_reply_setter(bool new_value);
            public bool wait_reply {
                get {
                    return wait_reply_getter();
                }
                set {
                    wait_reply_setter(value);
                }
            }
        }

        internal delegate string FakeRmt(string m_name, Gee.List<string> arguments) throws ZCDError, StubError;

        public interface IInfoManagerStub : Object
        {
            public abstract string get_name() throws StubError, DeserializeError;
            public abstract void set_name(string name) throws AuthError, BadArgsError, StubError, DeserializeError;
            public abstract int get_year() throws StubError, DeserializeError;
            public abstract bool set_year(int year) throws StubError, DeserializeError;
            public abstract License get_license() throws StubError, DeserializeError;
        }

        public interface ICalculatorStub : Object
        {
            public abstract IDocument get_root() throws StubError, DeserializeError;
            public abstract Gee.List<IDocument> get_children(IDocument parent) throws StubError, DeserializeError;
            public abstract void add_children(IDocument parent, Gee.List<IDocument> children) throws StubError, DeserializeError;
        }

        public interface INodeManagerStub : Object
        {
            protected abstract unowned IInfoManagerStub info_getter();
            public IInfoManagerStub info {get {return info_getter();}}
            protected abstract unowned ICalculatorStub calc_getter();
            public ICalculatorStub calc {get {return calc_getter();}}
        }

        public interface IChildrenViewerStub : Object
        {
            public abstract Gee.List<string> int_to_string(Gee.List<int> lst) throws StubError, DeserializeError;
        }

        public interface IStatisticsStub : Object
        {
            protected abstract unowned IChildrenViewerStub children_viewer_getter();
            public IChildrenViewerStub children_viewer {get {return children_viewer_getter();}}
        }

        public INodeManagerStub get_node_tcp_client(string peer_address, uint16 peer_port)
        {
            return new NodeManagerTcpClientRootStub(peer_address, peer_port);
        }

        public INodeManagerStub get_node_unicast(string dev, uint16 port, UnicastID unicast_id, bool wait_reply)
        {
            error("not implemented yet");
        }

        public INodeManagerStub get_node_broadcast(string dev, uint16 port, BroadcastID broadcast_id, bool send_ack)
        {
            error("not implemented yet");
        }

        public IStatisticsStub get_stats_tcp_client(string peer_address, uint16 peer_port)
        {
            return new StatisticsTcpClientRootStub(peer_address, peer_port);
        }

        public IStatisticsStub get_stats_unicast(string dev, uint16 port, UnicastID unicast_id, bool wait_reply)
        {
            error("not implemented yet");
        }

        public IStatisticsStub get_stats_broadcast(string dev, uint16 port, BroadcastID broadcast_id, bool send_ack)
        {
            error("not implemented yet");
        }

        internal class NodeManagerTcpClientRootStub : Object, INodeManagerStub, ITcpClientRootStub
        {
            private TcpClient client;
            private string peer_address;
            private uint16 peer_port;
            private bool hurry;
            private bool wait_reply;
            private InfoManagerRemote _info;
            private CalculatorRemote _calc;
            public NodeManagerTcpClientRootStub(string peer_address, uint16 peer_port)
            {
                this.peer_address = peer_address;
                this.peer_port = peer_port;
                client = tcp_client(peer_address, peer_port);
                hurry = false;
                wait_reply = true;
                _info = new InfoManagerRemote(this.call);
                _calc = new CalculatorRemote(this.call);
            }

            public bool hurry_getter()
            {
                return hurry;
            }

            public void hurry_setter(bool new_value)
            {
                hurry = new_value;
            }

            public bool wait_reply_getter()
            {
                return wait_reply;
            }

            public void wait_reply_setter(bool new_value)
            {
                wait_reply = new_value;
            }

            protected unowned IInfoManagerStub info_getter()
            {
                return _info;
            }

            protected unowned ICalculatorStub calc_getter()
            {
                return _calc;
            }

            private string call(string m_name, Gee.List<string> arguments) throws ZCDError, StubError
            {
                if (hurry && !client.is_queue_empty())
                {
                    client = tcp_client(peer_address, peer_port);
                }
                // TODO See destructor of TcpClient. If the low level library ZCD is able to ensure
                //  that the destructor is not called when a call is in progress, then this
                //  local_reference is not needed.
                TcpClient local_reference = client;
                string ret = local_reference.enqueue_call(m_name, arguments, wait_reply);
                if (!wait_reply) throw new StubError.DID_NOT_WAIT_REPLY(@"Didn't wait reply for a call to $(m_name)");
                return ret;
            }
        }

        internal class NodeManagerUnicastRootStub : Object, INodeManagerStub
        {
            private string s_unicast_id;
            private string dev;
            private uint16 port;
            private bool wait_reply;
            private InfoManagerRemote _info;
            private CalculatorRemote _calc;
            public NodeManagerUnicastRootStub(UnicastID unicast_id, string dev, uint16 port, bool wait_reply)
            {
                s_unicast_id = prepare_direct_object(unicast_id);
                this.dev = dev;
                this.port = port;
                this.wait_reply = wait_reply;
                _info = new InfoManagerRemote(this.call);
                _calc = new CalculatorRemote(this.call);
            }

            protected unowned IInfoManagerStub info_getter()
            {
                return _info;
            }

            protected unowned ICalculatorStub calc_getter()
            {
                return _calc;
            }

            private string call(string m_name, Gee.List<string> arguments) throws ZCDError, StubError
            {
                int id = Random.int_range(0, int.MAX);
                string k_map = @"$(dev):$(port)";
                ZcdUdpServiceMessageDelegate? del_ser = null;
                if (map_udp_listening != null && map_udp_listening.has_key(k_map))
                {
                    del_ser = map_udp_listening[k_map];
                }
                else
                {
                    wait_reply = false;
                }
                try {
                    send_unicast_request(dev, port, id, s_unicast_id, m_name, arguments, wait_reply);
                } catch (Error e) {
                    throw new StubError.GENERIC(e.message);
                }
                if (!wait_reply) throw new StubError.DID_NOT_WAIT_REPLY(@"Didn't wait reply for a call to $(m_name)");
                string ret = ""; // TODO
                return ret;
            }
        }

        internal class StatisticsTcpClientRootStub : Object, IStatisticsStub, ITcpClientRootStub
        {
            private TcpClient client;
            private string peer_address;
            private uint16 peer_port;
            private bool hurry;
            private bool wait_reply;
            private ChildrenViewerRemote _children_viewer;
            public StatisticsTcpClientRootStub(string peer_address, uint16 peer_port)
            {
                this.peer_address = peer_address;
                this.peer_port = peer_port;
                client = tcp_client(peer_address, peer_port);
                hurry = false;
                wait_reply = true;
                _children_viewer = new ChildrenViewerRemote(this.call);
            }

            public bool hurry_getter()
            {
                return hurry;
            }

            public void hurry_setter(bool new_value)
            {
                hurry = new_value;
            }

            public bool wait_reply_getter()
            {
                return wait_reply;
            }

            public void wait_reply_setter(bool new_value)
            {
                wait_reply = new_value;
            }

            protected unowned IChildrenViewerStub children_viewer_getter()
            {
                return _children_viewer;
            }

            private string call(string m_name, Gee.List<string> arguments) throws ZCDError, StubError
            {
                if (hurry && !client.is_queue_empty())
                {
                    client = tcp_client(peer_address, peer_port);
                }
                // TODO See destructor of TcpClient. If the low level library ZCD is able to ensure
                //  that the destructor is not called when a call is in progress, then this
                //  local_reference is not needed.
                TcpClient local_reference = client;
                string ret = local_reference.enqueue_call(m_name, arguments, wait_reply);
                if (!wait_reply) throw new StubError.DID_NOT_WAIT_REPLY(@"Didn't wait reply for a call to $(m_name)");
                return ret;
            }
        }

        internal class InfoManagerRemote : Object, IInfoManagerStub
        {
            private unowned FakeRmt rmt;
            public InfoManagerRemote(FakeRmt rmt)
            {
                this.rmt = rmt;
            }

            public string get_name() throws StubError, DeserializeError
            {
                string m_name = "node.info.get_name";
                ArrayList<string> args = new ArrayList<string>();

                string resp;
                try {
                    resp = rmt(m_name, args);
                }
                catch (ZCDError e) {
                    throw new StubError.GENERIC(e.message);
                }

                // deserialize response
                string? error_domain = null;
                string? error_code = null;
                string? error_message = null;
                string doing = @"Reading return-value of $(m_name)";
                string ret;
                try {
                    ret = read_return_value_string_notnull(resp, out error_domain, out error_code, out error_message);
                } catch (HelperNotJsonError e) {
                    error(@"Error parsing JSON for return-value of $(m_name): $(e.message)");
                } catch (HelperDeserializeError e) {
                    throw new DeserializeError.GENERIC(@"$(doing): $(e.message)");
                }
                if (error_domain != null)
                {
                    string error_domain_code = @"$(error_domain).$(error_code)";
                    throw new DeserializeError.GENERIC(@"$(doing): unrecognized error $(error_domain_code) $(error_message)");
                }
                return ret;
            }

            public void set_name(string arg0) throws AuthError, BadArgsError, StubError, DeserializeError
            {
                string m_name = "node.info.set_name";
                ArrayList<string> args = new ArrayList<string>();
                {
                    // serialize arg0 (string name)
                    args.add(prepare_argument_string(arg0));
                }

                string resp;
                try {
                    resp = rmt(m_name, args);
                }
                catch (ZCDError e) {
                    throw new StubError.GENERIC(e.message);
                }
                // The following catch is to be added only for methods that return void.
                catch (StubError.DID_NOT_WAIT_REPLY e) {return;}

                // deserialize response
                string? error_domain = null;
                string? error_code = null;
                string? error_message = null;
                string doing = @"Reading return-value of $(m_name)";
                try {
                    read_return_value_void(resp, out error_domain, out error_code, out error_message);
                } catch (HelperNotJsonError e) {
                    error(@"Error parsing JSON for return-value of $(m_name): $(e.message)");
                } catch (HelperDeserializeError e) {
                    throw new DeserializeError.GENERIC(@"$(doing): $(e.message)");
                }
                if (error_domain != null)
                {
                    string error_domain_code = @"$(error_domain).$(error_code)";
                    if (error_domain_code == "AuthError.GENERIC")
                        throw new AuthError.GENERIC(error_message);
                    if (error_domain_code == "BadArgsError.GENERIC")
                        throw new BadArgsError.GENERIC(error_message);
                    if (error_domain_code == "BadArgsError.NULL_NOT_ALLOWED")
                        throw new BadArgsError.NULL_NOT_ALLOWED(error_message);
                    throw new DeserializeError.GENERIC(@"$(doing): unrecognized error $(error_domain_code) $(error_message)");
                }
                return;
            }

            public int get_year() throws StubError, DeserializeError
            {
                string m_name = "node.info.get_year";
                ArrayList<string> args = new ArrayList<string>();

                string resp;
                try {
                    resp = rmt(m_name, args);
                }
                catch (ZCDError e) {
                    throw new StubError.GENERIC(e.message);
                }

                // deserialize response
                string? error_domain = null;
                string? error_code = null;
                string? error_message = null;
                string doing = @"Reading return-value of $(m_name)";
                int ret;
                int64 val;
                try {
                    val = read_return_value_int64_notnull(resp, out error_domain, out error_code, out error_message);
                } catch (HelperNotJsonError e) {
                    error(@"Error parsing JSON for return-value of $(m_name): $(e.message)");
                } catch (HelperDeserializeError e) {
                    throw new DeserializeError.GENERIC(@"$(doing): $(e.message)");
                }
                if (error_domain != null)
                {
                    string error_domain_code = @"$(error_domain).$(error_code)";
                    throw new DeserializeError.GENERIC(@"$(doing): unrecognized error $(error_domain_code) $(error_message)");
                }
                if (val > int.MAX || val < int.MIN)
                    throw new DeserializeError.GENERIC(@"$(doing): return-value overflows size of int");
                ret = (int)val;
                return ret;
            }

            public bool set_year(int arg0) throws StubError, DeserializeError
            {
                string m_name = "node.info.set_year";
                ArrayList<string> args = new ArrayList<string>();
                {
                    // serialize arg0 (int year)
                    args.add(prepare_argument_int64(arg0));
                }

                string resp;
                try {
                    resp = rmt(m_name, args);
                }
                catch (ZCDError e) {
                    throw new StubError.GENERIC(e.message);
                }

                // deserialize response
                string? error_domain = null;
                string? error_code = null;
                string? error_message = null;
                string doing = @"Reading return-value of $(m_name)";
                bool ret;
                try {
                    ret = read_return_value_bool_notnull(resp, out error_domain, out error_code, out error_message);
                } catch (HelperNotJsonError e) {
                    error(@"Error parsing JSON for return-value of $(m_name): $(e.message)");
                } catch (HelperDeserializeError e) {
                    throw new DeserializeError.GENERIC(@"$(doing): $(e.message)");
                }
                if (error_domain != null)
                {
                    string error_domain_code = @"$(error_domain).$(error_code)";
                    throw new DeserializeError.GENERIC(@"$(doing): unrecognized error $(error_domain_code) $(error_message)");
                }
                return ret;
            }

            public License get_license() throws StubError, DeserializeError
            {
                string m_name = "node.info.get_license";
                ArrayList<string> args = new ArrayList<string>();

                string resp;
                try {
                    resp = rmt(m_name, args);
                }
                catch (ZCDError e) {
                    throw new StubError.GENERIC(e.message);
                }

                // deserialize response
                string? error_domain = null;
                string? error_code = null;
                string? error_message = null;
                string doing = @"Reading return-value of $(m_name)";
                Object ret;
                try {
                    ret = read_return_value_object_notnull(typeof(License), resp, out error_domain, out error_code, out error_message);
                } catch (HelperNotJsonError e) {
                    error(@"Error parsing JSON for return-value of $(m_name): $(e.message)");
                } catch (HelperDeserializeError e) {
                    throw new DeserializeError.GENERIC(@"$(doing): $(e.message)");
                }
                if (error_domain != null)
                {
                    string error_domain_code = @"$(error_domain).$(error_code)";
                    throw new DeserializeError.GENERIC(@"$(doing): unrecognized error $(error_domain_code) $(error_message)");
                }
                if (ret is ISerializable)
                    if (!((ISerializable)ret).check_serialization())
                        throw new DeserializeError.GENERIC(@"$(doing): instance of $(ret.get_type().name()) has not been fully deserialized");
                return (License)ret;
            }
        }

        internal class CalculatorRemote : Object, ICalculatorStub
        {
            private unowned FakeRmt rmt;
            public CalculatorRemote(FakeRmt rmt)
            {
                this.rmt = rmt;
            }

            public IDocument get_root() throws StubError, DeserializeError
            {
                string m_name = "node.calc.get_root";
                ArrayList<string> args = new ArrayList<string>();

                string resp;
                try {
                    resp = rmt(m_name, args);
                }
                catch (ZCDError e) {
                    throw new StubError.GENERIC(e.message);
                }

                // deserialize response
                string? error_domain = null;
                string? error_code = null;
                string? error_message = null;
                string doing = @"Reading return-value of $(m_name)";
                Object ret;
                try {
                    ret = read_return_value_object_notnull(typeof(IDocument), resp, out error_domain, out error_code, out error_message);
                } catch (HelperNotJsonError e) {
                    error(@"Error parsing JSON for return-value of $(m_name): $(e.message)");
                } catch (HelperDeserializeError e) {
                    throw new DeserializeError.GENERIC(@"$(doing): $(e.message)");
                }
                if (error_domain != null)
                {
                    string error_domain_code = @"$(error_domain).$(error_code)";
                    throw new DeserializeError.GENERIC(@"$(doing): unrecognized error $(error_domain_code) $(error_message)");
                }
                if (ret is ISerializable)
                    if (!((ISerializable)ret).check_serialization())
                        throw new DeserializeError.GENERIC(@"$(doing): instance of $(ret.get_type().name()) has not been fully deserialized");
                return (IDocument)ret;
            }

            public Gee.List<IDocument> get_children(IDocument arg0) throws StubError, DeserializeError
            {
                string m_name = "node.calc.get_children";
                ArrayList<string> args = new ArrayList<string>();
                {
                    // serialize arg0 (IDocument parent)
                    args.add(prepare_argument_object(arg0));
                }

                string resp;
                try {
                    resp = rmt(m_name, args);
                }
                catch (ZCDError e) {
                    throw new StubError.GENERIC(e.message);
                }

                // deserialize response
                string? error_domain = null;
                string? error_code = null;
                string? error_message = null;
                string doing = @"Reading return-value of $(m_name)";
                Gee.List<IDocument> ret;
                try {
                    ret = (Gee.List<IDocument>)
                        read_return_value_array_of_object
                        (typeof(IDocument), resp, out error_domain, out error_code, out error_message);
                } catch (HelperNotJsonError e) {
                    error(@"Error parsing JSON for return-value of $(m_name): $(e.message)");
                } catch (HelperDeserializeError e) {
                    throw new DeserializeError.GENERIC(@"$(doing): $(e.message)");
                }
                return ret;
            }

            public void add_children(IDocument arg0, Gee.List<IDocument> arg1) throws StubError, DeserializeError
            {
                string m_name = "node.calc.add_children";
                ArrayList<string> args = new ArrayList<string>();
                {
                    // serialize arg0 (IDocument parent)
                    args.add(prepare_argument_object(arg0));
                }
                {
                    // serialize arg1 (Gee.List<IDocument> children)
                    args.add(prepare_argument_array_of_object(arg1));
                }

                string resp;
                try {
                    resp = rmt(m_name, args);
                }
                catch (ZCDError e) {
                    throw new StubError.GENERIC(e.message);
                }
                // The following catch is to be added only for methods that return void.
                catch (StubError.DID_NOT_WAIT_REPLY e) {return;}

                // deserialize response
                string? error_domain = null;
                string? error_code = null;
                string? error_message = null;
                string doing = @"Reading return-value of $(m_name)";
                try {
                    read_return_value_void(resp, out error_domain, out error_code, out error_message);
                } catch (HelperNotJsonError e) {
                    error(@"Error parsing JSON for return-value of $(m_name): $(e.message)");
                } catch (HelperDeserializeError e) {
                    throw new DeserializeError.GENERIC(@"$(doing): $(e.message)");
                }
                if (error_domain != null)
                {
                    string error_domain_code = @"$(error_domain).$(error_code)";
                    throw new DeserializeError.GENERIC(@"$(doing): unrecognized error $(error_domain_code) $(error_message)");
                }
                return;
            }
        }

        internal class ChildrenViewerRemote : Object, IChildrenViewerStub
        {
            private unowned FakeRmt rmt;
            public ChildrenViewerRemote(FakeRmt rmt)
            {
                this.rmt = rmt;
            }

            public Gee.List<string> int_to_string(Gee.List<int> arg0) throws StubError, DeserializeError
            {
                string m_name = "stats.children_viewer.int_to_string";
                ArrayList<string> args = new ArrayList<string>();
                {
                    // serialize arg0 (Gee.List<int> lst)
                    ArrayList<int64?> lst = new ArrayList<int64?>();
                    foreach (int el_i in arg0) lst.add(el_i);
                    args.add(prepare_argument_array_of_int64(lst));
                }

                string resp;
                try {
                    resp = rmt(m_name, args);
                }
                catch (ZCDError e) {
                    throw new StubError.GENERIC(e.message);
                }

                // deserialize response
                string? error_domain = null;
                string? error_code = null;
                string? error_message = null;
                string doing = @"Reading return-value of $(m_name)";
                Gee.List<string> ret;
                try {
                    ret = read_return_value_array_of_string
                        (resp, out error_domain, out error_code, out error_message);
                } catch (HelperNotJsonError e) {
                    error(@"Error parsing JSON for return-value of $(m_name): $(e.message)");
                } catch (HelperDeserializeError e) {
                    throw new DeserializeError.GENERIC(@"$(doing): $(e.message)");
                }
                return ret;
            }
        }
    }
}

