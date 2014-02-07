Ldap2PostfixMap
============

Présentation
------------

Cet outil est destiné à alimenter une table d'adresses virtuelles pour Postfix depuis les attributs email d'un serveur LDAP.

Le domaine virtuel doit être préalablement déclaré dans le configuration de Postfix (/etc/postfix/main.cf) par exemple comme 'virtual_alias_domain'.
Le fichier contenant la table d'adresses virtuelles doit préalablement être déclarée commme 'virtual_alias_maps' dans la configuration de Postfix (/etc/postfix/main.cf).

Pour une aide complète sur les options supportées, installez le script et lancez l'aide :

    ./Ldap2PostfixMap.sh help


Bug report
-------------

Si vous voulez me faire remonter un bug : [ouvrir un bug](https://github.com/ygodard/ldap2postfixmap/issues).


Installation
---------

Pour installer cet outil, depuis votre terminal :

	git clone https://github.com/yvangodard/Ldap2PostfixMap.git ; 
	sudo chmod -R 750 Ldap2PostfixMap


License
-------

Ce script ldap2mailman.sh de [Yvan GODARD](http://www.yvangodard.me) est mis à disposition selon les termes de la licence Creative Commons 4.0 BY NC SA (Attribution - Pas d’Utilisation Commerciale - Partage dans les Mêmes Conditions).

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0"><img alt="Licence Creative Commons" style="border-width:0" src="http://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a>


Limitations
-----------

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.